#include <stdio.h>
#include <uv.h>
#include <stdbool.h>


#ifdef _WIN32
#define PATHSEP "\\"
#else
#define PATHSEP "/"
#endif

static uv_loop_t* thread_loop;
static pthread_t thread_id;

typedef struct {
    int code;
    char *message;
    int ownership;
} result_t;

// void result_cleanup(result_t *output){
//     if (output->ownership && output->message != NULL) {
//         free(output->message);
//         free(output);
//     }
//     return;
// }

void result_cleanup(result_t output){
    if (output.ownership && output.message != NULL) {
        free(output.message);
    }
    return;
}


bool path_exists(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0);
}

bool is_directory(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0)
        return false;
    return S_ISDIR(st.st_mode);
}

bool is_file(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0)
        return false;
    return S_ISREG(st.st_mode);
}

void* loop_thread_func(void* arg) {
    uv_run(thread_loop, UV_RUN_DEFAULT);
    uv_loop_close(thread_loop);
    free(thread_loop);
    return NULL;
}

void start_libuv_thread() {
    thread_loop = malloc(sizeof(uv_loop_t));
    uv_loop_init(thread_loop);
    pthread_create(&thread_id, NULL, loop_thread_func, NULL);
}

void stop_libuv_thread() {
    uv_stop(thread_loop);
    pthread_join(thread_id, NULL);
}

void on_copy_done(uv_fs_t* req) {
    if (req->result < 0) {
        fprintf(stderr, "Copy failed: %s\n", uv_strerror((int)req->result));
    } else {
        printf("Copy finished successfully!\n");
    }
    uv_fs_req_cleanup(req);
    free(req);
}

void copy_file(const char* src, const char* dst) {
    uv_fs_t* req = malloc(sizeof(uv_fs_t));
    uv_fs_copyfile(thread_loop, src, dst, 0, req, on_copy_done);
}

void fs_init() {
    start_libuv_thread();
}

void fs_shutdown() {
    stop_libuv_thread();
}


static void ensure_dir(const char* path) {
    uv_fs_t req;
    uv_fs_mkdir(thread_loop, &req, path, 0755, NULL); // sync mkdir
    uv_fs_req_cleanup(&req);
}

void copy_dir(const char* src, const char* dst){
    uv_fs_t req;
    uv_dirent_t dent;

    // Create the destination folder
    ensure_dir(dst);

    // Open the source dir
    if (uv_fs_scandir(thread_loop, &req, src, 0, NULL) < 0) {
        fprintf(stderr, "Error scanning dir: %s\n", src);
        uv_fs_req_cleanup(&req);
        return;
    }

    // Iterate entries
    while (UV_EOF != uv_fs_scandir_next(&req, &dent)) {
        char src_path[PATH_MAX];
        char dst_path[PATH_MAX];
        snprintf(src_path, sizeof(src_path), "%s/%s", src, dent.name);
        // snprintf(dst_path, sizeof(dst_path), "%s/%s", dst, dent.name);

        // if (dent.type == UV_DIRENT_DIR) {
        //     // Skip "." and ".."
        //     if (strcmp(dent.name, ".") == 0 || strcmp(dent.name, "..") == 0)
        //         continue;
        //     copy_dir_recursive(src_path, dst_path);
        // } else if (dent.type == UV_DIRENT_FILE) {
        //     copy_file_async(src_path, dst_path);
        // }
        copy_to(src_path,dst);

    }

    uv_fs_req_cleanup(&req);
}

const char* get_basename(const char* path) {
    size_t len = strlen(path);

    // Strip trailing slashes (both Unix and Windows)
    while (len > 0 && (path[len - 1] == '/' || path[len - 1] == '\\')) {
        len--;
    }

    // If path was just "/" or "\" or empty, return separator or empty string
    if (len == 0) return path;

    // Work on the stripped version
    const char* last_slash = memrchr(path, '/', len); // GNU extension
#ifdef _WIN32
    const char* last_backslash = memrchr(path, '\\', len);
    if (last_backslash && (!last_slash || last_backslash > last_slash)) {
        last_slash = last_backslash;
    }
#endif

    if (last_slash) {
        return last_slash + 1; // Skip separator
    } else {
        return path; // No separator found
    }
}


char* check_name(char* fs_src_path, char* fs_dest_directory){
    // const char* base = strrchr(fs_src_path, '/');
    // #ifdef _WIN32
    //     const char* base_win = strrchr(fs_src_path, '\\');
    //     if (base_win && (!base || base_win > base)) base = base_win;
    // #endif
    // base = base ? base + 1 : fs_src_path;

    char* base = get_basename(fs_src_path);
    
    char* dest = malloc(strlen(fs_dest_directory) + 1 + strlen(base) + 32);
    if (!dest) return NULL;

    strcpy(dest, fs_dest_directory);
    strcat(dest, PATHSEP);
    strcat(dest, base);

    int counter = 1;

    while (fsutils_is_object_exist(dest)) {
        // Split name and extension
        char name[256], ext[256];
        const char* dot = strrchr(base, '.');
        if (dot) {
            size_t nlen = dot - base;
            strncpy(name, base, nlen);
            name[nlen] = '\0';
            strcpy(ext, dot);
        } else {
            strcpy(name, base);
            ext[0] = '\0';
        }

        snprintf(dest, 1024, "%s%s%s (%d)%s",
                 fs_dest_directory, PATHSEP, name, counter, ext);
        counter++;
    }

    return dest;
}

result_t copy_to(const char* src, const char* dest_directory) {
    result_t output = {
        .code=0,
        .message=NULL, 
        .ownership = 0, 
    };

    if (!path_exists(src)){
        output.code = -1;
        output.ownership = 1;
        char* buf = malloc(PATH_MAX);
        snprintf(buf, PATH_MAX, "Path does not exist: %s", src);
        output.message = buf;
        return output;
    }

    // if (!is_directory(dest_directory)){
    //     output.code = -1;
    //     output.ownership = 1;
    //     char* buf = malloc(1000);
    //     snprintf(buf, 1000, "Given destination is not a directory: %s", dest_directory);
    //     output.message = buf;
    //     return output;
    // }

    char *dest = check_name(src,dest_directory);

    if(is_file(src)){
        copy_file(src,dest);
    }
    else if(is_directory(src))
    {
         copy_dir(src,dest);
    }
    else{
        output.code = -1;
        output.ownership = 0;
        output.message = "Source path is neither file or directory, cannot handle case";
        return output;
    }
    

}