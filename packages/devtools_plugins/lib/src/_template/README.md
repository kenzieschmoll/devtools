The code in this directory is for the DevTools plugin template that package
authors will use to build DevTools plugins. Files in this directory are
exported through the `lib/devtools_plugin_template.dart` file.

This code is not intended to be imported into DevTools itself. Anything that
should be shared between DevTools and DevTools plugins will be under the
`src/shared` directory and exported through `lib/devtools_plugins.dart`.