/* Migration shim -- NOT part of the Prismio runtime, never linked into a release.
 *
 * runtime/program_support.c reads two globals, prismio_argc / prismio_argv, that
 * are *defined by generated code*: generate_module() in src/ir.psm emits them and
 * generate_function() fills them from main's real argc/argv. That is what makes
 * cli_arg()/cli_arg_count() behave identically on Windows, Linux and macOS.
 *
 * A compiler generation built before that change emits IR without those globals,
 * so linking its output against the current runtime fails with
 * "undefined symbol: prismio_argc". Pass -ArgvShim to tools/bootstrap.ps1 for that
 * one stage: this file supplies the definitions and populates them from the
 * Windows CRT's __argc/__argv so the stage-A compiler still sees its command line.
 *
 * The resulting compiler emits the globals itself, so the stage that follows links
 * without the shim and it is never needed again.
 */

int prismio_argc = 0;
char** prismio_argv = 0;

#ifdef _WIN32
extern int __argc;
extern char** __argv;

__attribute__((constructor))
static void prismio_bootstrap_capture_argv(void) {
    prismio_argc = __argc;
    prismio_argv = __argv;
}
#endif
