#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <pthread.h>


#define LITE_XL_PLUGIN_ENTRYPOINT
#include <lite_xl_plugin_api.h>


#if LUA_VERSION_NUM >= 502
#define new_lib(L, l) (luaL_newlib(L, l))
#else
#define new_lib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))
#endif

#define CPLUA_VERSION "0.1.0"

#ifdef _WIN32
  #include <windows.h>
  #include <shlobj.h>  // For DROPFILES and DragQueryFile
#else
  #include <X11/Xlib.h>
  #include <X11/Xatom.h>
#endif

#include "cplua.h"
// #include "libclipboard.h"

static int pusherror(lua_State * L, const char *info)
{
  lua_pushnil(L);
  if (info == NULL)
    lua_pushstring(L, strerror(errno));
  else
    lua_pushfstring(L, "%s: %s", info, strerror(errno));
  lua_pushinteger(L, errno);
  return 3;
}

static int pushresult(lua_State * L, int res, const char *info)
{
  if (res == -1) {
    return pusherror(L, info);
  } else {
    lua_pushboolean(L, 1);
    return 1;
  }
}

#ifdef _WIN32

  void copy_files_to_clipboard(const char **filepaths, int file_count) {
      if (file_count <= 0) return;

      // Calculate required memory size
      size_t total_path_len = 0;
      for (int i = 0; i < file_count; ++i) {
          total_path_len += strlen(filepaths[i]) + 1; // +1 for null terminator
      }
      total_path_len += 1; // Extra null terminator for double-null ending

      size_t dropfiles_size = sizeof(DROPFILES) + total_path_len;

      // Allocate global memory
      HGLOBAL hGlobal = GlobalAlloc(GHND | GMEM_SHARE, dropfiles_size);
      if (!hGlobal) return;

      DROPFILES *df = (DROPFILES *)GlobalLock(hGlobal);
      if (!df) {
          GlobalFree(hGlobal);
          return;
      }

      // Fill DROPFILES header
      df->pFiles = sizeof(DROPFILES);
      df->pt.x = 0;
      df->pt.y = 0;
      df->fNC = FALSE;
      df->fWide = FALSE; // Use ANSI strings (could be TRUE for Unicode)

      // Write file paths after DROPFILES structure
      char *paths = (char *)df + sizeof(DROPFILES);
      for (int i = 0; i < file_count; ++i) {
          strcpy(paths, filepaths[i]);
          paths += strlen(filepaths[i]) + 1;
      }
      *paths = '\0'; // Double-null terminate

      GlobalUnlock(hGlobal);

      // Open clipboard and set data
      if (OpenClipboard(NULL)) {
          EmptyClipboard();
          SetClipboardData(CF_HDROP, hGlobal);
          CloseClipboard();
      } else {
          GlobalFree(hGlobal); // Only free if not set in clipboard
      }
  }

  void paste_files_from_clipboard() {
      if (!OpenClipboard(NULL)) {
          printf("Failed to open clipboard\n");
          return;
      }

      if (!IsClipboardFormatAvailable(CF_HDROP)) {
          printf("Clipboard does not contain file paths\n");
          CloseClipboard();
          return;
      }

      HANDLE hDrop = GetClipboardData(CF_HDROP);
      if (hDrop == NULL) {
          printf("Failed to get CF_HDROP data\n");
          CloseClipboard();
          return;
      }

      HDROP hDropHandle = (HDROP)hDrop;

      // Get number of files/directories
      UINT fileCount = DragQueryFile(hDropHandle, 0xFFFFFFFF, NULL, 0);
      printf("Clipboard contains %u items:\n", fileCount);

      // Iterate over all file paths
      for (UINT i = 0; i < fileCount; ++i) {
          char filepath[MAX_PATH];
          if (DragQueryFile(hDropHandle, i, filepath, MAX_PATH)) {
              printf("  %s\n", filepath);
          }
      }

      CloseClipboard();
  }

  bool is_directory(const char *path) {
      DWORD attrs = GetFileAttributesA(path);
      return (attrs != INVALID_FILE_ATTRIBUTES) && (attrs & FILE_ATTRIBUTE_DIRECTORY);
  }

#else

typedef struct {
    Display *dpy;
    Window win;
    Atom clipboard;
    Atom targets_atom;
    Atom gnome_atom;
    Atom utf8_atom;
    Atom text_atom;
    Atom uri_list_atom;

    char *current_uri;       // clipboard data, format "copy\nfile://...path...\n"
    bool running;

    pthread_mutex_t mutex;
    pthread_cond_t cond;
} ClipboardState;

static void free_uri(char **uri_ptr) {
    if (*uri_ptr) {
        free(*uri_ptr);
        *uri_ptr = NULL;
    }
}

static void update_clipboard_data(ClipboardState *state, const char *new_uri) {
    pthread_mutex_lock(&state->mutex);
    free_uri(&state->current_uri);
    state->current_uri = strdup(new_uri);
    pthread_cond_signal(&state->cond);
    pthread_mutex_unlock(&state->mutex);
}

void print_uri_content(const char *uri, size_t max_len) {
    if (!uri) {
        printf("URI is NULL\n");
        return;
    }

    printf("URI bytes: ");
    for (size_t i = 0; i < max_len; i++) {
        unsigned char c = (unsigned char)uri[i];
        if (c == '\0') {
            printf("\\0");  // null terminator found
            break;
        } else if (c >= 32 && c <= 126) {  // printable ASCII
            putchar(c);
        } else {
            printf("\\x%02x", c);  // non-printable byte in hex
        }
    }
    printf("\n");
}

static void handle_selection_request(ClipboardState *state, XSelectionRequestEvent *req) {
    XSelectionEvent sev = {0};
    sev.type = SelectionNotify;
    sev.display = req->display;
    sev.requestor = req->requestor;
    sev.selection = req->selection;
    sev.time = req->time;
    sev.target = req->target;
    sev.property = req->property;

    char *tname  = XGetAtomName(state->dpy, req->target);
    printf("[DEBUG CPLUA] SelectionRequest for target: %s, send_event %s\n",
       tname, req->send_event ? "true" : "false");

    
    if (req->target == state->targets_atom) {
        printf("[DEBUG CPLUA] target atom requested\n");
        Atom available_targets[] = { state->gnome_atom, state->uri_list_atom, state->utf8_atom, state->text_atom };
        XChangeProperty(state->dpy, req->requestor, req->property, XA_ATOM, 32,
                        PropModeReplace, (unsigned char *)available_targets, 4);
    }
    else if (req->target == state->uri_list_atom){
        printf("[DEBUG CPLUA] uri atom requested\n");
        pthread_mutex_lock(&state->mutex);
        if (state->current_uri) {
            XChangeProperty(state->dpy, req->requestor, req->property, state->uri_list_atom, 8,
                            PropModeReplace, (unsigned char *)state->current_uri,
                            strlen(state->current_uri));
        } else {
            sev.property = None;
        }
        pthread_mutex_unlock(&state->mutex);
    }
     else if (req->target == state->gnome_atom) {
        printf("[DEBUG CPLUA] gnome atom requested\n");
        pthread_mutex_lock(&state->mutex);
        if (state->current_uri) {
            char buf[4096];
            snprintf(buf, sizeof(buf), "copy\n%s", state->current_uri);
            printf("[DEBUG CPLUA] sending buffer:%s",buf);
            print_uri_content(buf,200);
            XChangeProperty(state->dpy, req->requestor, req->property, state->gnome_atom, 8,
                            PropModeReplace, (unsigned char *)buf, strlen(buf));
        } else {
            printf("[DEBUG CPLUA] no current uri found");
            sev.property = None;
        }
        pthread_mutex_unlock(&state->mutex);
    } else if (req->target == state->utf8_atom || req->target == state->text_atom) {
        printf("[DEBUG CPLUA] text atom requested\n");
        pthread_mutex_lock(&state->mutex);
        if (state->current_uri) {
            XChangeProperty(state->dpy, req->requestor, req->property, state->utf8_atom, 8,
                            PropModeReplace, (unsigned char *)state->current_uri, strlen(state->current_uri));
        } else {
            sev.property = None;
        }
        pthread_mutex_unlock(&state->mutex);
    } else {
        printf("[DEBUG CPLUA] no matching target found in request\n");
        sev.property = None; // unsupported target
    }

    XSendEvent(state->dpy, req->requestor, False, 0, (XEvent *)&sev);
    XFlush(state->dpy);
}

static void *clipboard_thread_func(void *arg) {
    printf("[DEBUG CPLUA] start thread function\n");
    ClipboardState *state = (ClipboardState *)arg;

    state->dpy = XOpenDisplay(NULL);
    if (!state->dpy) {
        fprintf(stderr, "[clipboard] Failed to open X display\n");
        return NULL;
    }

    state->win = XCreateSimpleWindow(state->dpy, DefaultRootWindow(state->dpy),
                                     0, 0, 1, 1, 0, 0, 0);

    state->clipboard = XInternAtom(state->dpy, "CLIPBOARD", False);
    state->targets_atom = XInternAtom(state->dpy, "TARGETS", False);
    state->gnome_atom = XInternAtom(state->dpy, "x-special/gnome-copied-files", False);
    state->utf8_atom = XInternAtom(state->dpy, "UTF8_STRING", False);
    state->text_atom = XInternAtom(state->dpy, "TEXT", False);
    state->uri_list_atom = XInternAtom(state->dpy, "text/uri-list", False);

    XSetSelectionOwner(state->dpy, state->clipboard, state->win, CurrentTime);

    if (XGetSelectionOwner(state->dpy, state->clipboard) != state->win) {
        fprintf(stderr, "[clipboard] Failed to own clipboard\n");
        XDestroyWindow(state->dpy, state->win);
        XCloseDisplay(state->dpy);
        return NULL;
    }

    printf("[clipboard] Clipboard thread started, owning clipboard.\n");

    XEvent event;

    while (1) {
        printf("[DEBUG CPLUA] running thread loop\n");
        while (XPending(state->dpy)) {
            XNextEvent(state->dpy, &event);

            if (event.type == SelectionRequest) {
                handle_selection_request(state, &event.xselectionrequest);
            }
        }

        // Wait for new data or exit signal
        pthread_mutex_lock(&state->mutex);
        if (!state->running) {
            pthread_mutex_unlock(&state->mutex);
            break;
        }
        // Wait with timeout to re-check XPending in case of new events
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_sec += 1;
        pthread_cond_timedwait(&state->cond, &state->mutex, &ts);
        pthread_mutex_unlock(&state->mutex);
    }

    // Clean up
    free_uri(&state->current_uri);
    XDestroyWindow(state->dpy, state->win);
    XCloseDisplay(state->dpy);

    printf("[clipboard] Clipboard thread exiting.\n");

    return NULL;
}

// --- Public API ---

static ClipboardState clipboard_state = {
    .current_uri = NULL,
    .running = False,
    .mutex = PTHREAD_MUTEX_INITIALIZER,
    .cond = PTHREAD_COND_INITIALIZER,
};

static pthread_t clipboard_thread;

void clipboard_start_thread() {
    printf("[DEBUG CPLUA] start thread\n");
    pthread_mutex_lock(&clipboard_state.mutex);
    if (!clipboard_state.running) {
        clipboard_state.running = True;
        pthread_create(&clipboard_thread, NULL, clipboard_thread_func, &clipboard_state);
    }
    pthread_mutex_unlock(&clipboard_state.mutex);
}

void clipboard_stop_thread() {
    printf("[DEBUG CPLUA] exiting cplua thread\n");
    pthread_mutex_lock(&clipboard_state.mutex);
    if (clipboard_state.running) {
        clipboard_state.running = False;
        pthread_cond_signal(&clipboard_state.cond);
        // printf("[DEBUG CPLUA] sending exit cond signal\n");
        pthread_mutex_unlock(&clipboard_state.mutex);
        pthread_join(clipboard_thread, NULL);
        // free_uri(clipboard_state.current_uri);
    } else {
        pthread_mutex_unlock(&clipboard_state.mutex);
    }
}

void copy_file_to_clipboard(const char *filepath) {
    // Compose URI string with newline
    char uri[4096];
    // snprintf(uri, sizeof(uri), "copy\nfile://%s\n", filepath);
    snprintf(uri, sizeof(uri), "file://%s", filepath);

    // char gnome_clip[4100];
    // snprintf(gnome_clip, sizeof(gnome_clip), "copy\nfile://%s\n", filepath);


    printf("[DEBUG CPLUA] uri : %s\n", uri);
    
    update_clipboard_data(&clipboard_state, uri);
}

#endif

static int clipboard_fs_copy(lua_State * L)
{
    
    const char *path = luaL_checkstring(L, 1); 
    printf("[DEBUG CPLUA] path: %s\n", path);

    //   copy_files_to_clipboard(path);
    copy_file_to_clipboard(path);
    return ;
}

static const struct luaL_Reg cplua_api[] = {
  { "copy", clipboard_fs_copy },
  // { "paste", clipboard_fs_paste },
  { "on_quit", clipboard_stop_thread },
  { NULL, NULL },
};

static int common_lfs_init(lua_State* L){
    
    luaL_newmetatable(L, "cplua");
    //   dir_create_meta(L);
    //   lock_create_meta(L);
    luaL_setfuncs(L, cplua_api, 0);

    #ifndef _WIN32
    clipboard_start_thread();
    #endif

    lua_pushliteral(L, CPLUA_VERSION);
    lua_setfield(L, -2, "version");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    // if (!gtk_init_check(NULL, NULL)) {
    //     fprintf(stderr, "Failed to initialize GTK\n");
    //     lua_pushboolean(L, 0);
    //     return 0;
    // }

    return 1;
}

CPLUA_EXPORT int luaopen_cplua(lua_State* L) {
    return common_lfs_init(L);
}

CPLUA_EXPORT int luaopen_lite_xl_cplua(lua_State* L, void* XL) {
    printf("[DEBUG CPLUA] init\n");
    lite_xl_plugin_init(XL);
    return common_lfs_init(L);
};