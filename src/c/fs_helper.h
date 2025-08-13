#ifdef __cplusplus
extern "C" {
#endif

void fs_init();
void fs_shutdown();

void copy_file(const char* src, const char* dst);
void copy_to(const char* src, const char* dst);
void copy_dir(const char* src, const char* dst);
char* check_name(char* fs_src_path, char* fs_dest_directory);

#ifdef __cplusplus
}
#endif