#ifdef __cplusplus
extern "C" {
#endif

void fs_init();
void fs_shutdown();

void copy_file_async(const char* src, const char* dst);

#ifdef __cplusplus
}
#endif