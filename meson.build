project('io.github.phase1geo.minder', ['vala', 'c'],
    version : '3.0.0',
    license: 'GPL-3.0'
)

add_project_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())
    ],
    language: 'c',
)

gnome = import('gnome')
i18n = import('i18n')

gresource = gnome.compile_resources(
    'minder-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
)

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

sources = files()

subdir('data')
subdir('po')
subdir('src')

# Add the math and Markdown libraries
cc = meson.get_compiler('c')
math_dep = cc.find_library('m', required: false)

# Check libmarkdown2 dependency
libmarkdown = dependency('libmarkdown', required: true)
librsvg = dependency('librsvg-2.0', version: '>=2.52', required: true)
markdown_vapi = '/vapi/libmarkdown.vapi'
if libmarkdown.version().version_compare('>=3.0')
  add_project_arguments(['--define=MD30'], language: 'vala')
endif

add_project_arguments([
        '--vapidir=' + join_paths(meson.project_source_root(), 'vapi')
        # '--disable-warnings'
    ],
    language: 'vala',
)

# Some platforms (e.g. Homebrew) ship librsvg without a Vala binding; fall back
# to the minimal in-tree binding only when the system has none.
if not meson.get_compiler('vala').find_library('librsvg-2.0', required: false).found()
  add_project_arguments([
      '--vapidir=' + join_paths(meson.project_source_root(), 'vapi', 'fallback')
  ], language: 'vala')
endif

add_project_arguments(['-w'], language: 'c')

dependencies = [
    dependency('gobject-2.0'),
    dependency('glib-2.0'),
    dependency('cairo'),
    dependency('gee-0.8'),
    dependency('gtk4'),
    dependency('libxml-2.0'),
    dependency('libarchive'),
    dependency('gtksourceview-5'),
    dependency('json-glib-1.0'),
    dependency('libwebp'),
    libmarkdown,
    librsvg,
    math_dep
]

# GAction with a live-computed enabled state (implemented in C: see live-action.c)
sources += files('src/live-action.c')

# Native macOS print panel (Objective-C): the Homebrew GTK has no CUPS backend
mac_link_args = []
if host_machine.system() == 'darwin'
  add_languages('objc', native: false)
  add_project_arguments(['-fobjc-arc'], language: 'objc')
  add_project_arguments(['--define=MACOS_PRINT'], language: 'vala')
  add_project_arguments(['--define=MACOS_WINDOW'], language: 'vala')
  sources += files('src/macos-print.m', 'src/macos-window.m')
  mac_link_args = ['-framework', 'Cocoa', '-framework', 'PDFKit']
endif

# Optional components (see meson_options.txt)
extra_vala_args = [
    join_paths(meson.project_source_root(), 'vapi', 'fallback', 'live-action.vapi'),
    join_paths(meson.project_source_root(), 'vapi', 'libmarkdown.vapi'),
    join_paths(meson.project_source_root(), 'vapi', 'libwebp.vapi'),
]

if libmarkdown.version().version_compare('>=3.0')
  extra_vala_args += join_paths(meson.project_source_root(), 'vapi', 'libmarkdown3.vapi')
endif

if host_machine.system() == 'darwin'
  extra_vala_args += join_paths(meson.project_source_root(), 'vapi', 'fallback', 'macos-print.vapi')
  extra_vala_args += join_paths(meson.project_source_root(), 'vapi', 'fallback', 'macos-window.vapi')
endif

if get_option('granite')
  dependencies += dependency('granite-7')
else
  dependencies += dependency('libadwaita-1', version: '>=1.2')
  sources += files('src/compat/Granite.vala')
endif

primary_modifier = get_option('primary-modifier')
if primary_modifier == 'auto'
  primary_modifier = (host_machine.system() == 'darwin') ? 'command' : 'control'
endif
if primary_modifier == 'command'
  add_project_arguments(['--define=PRIMARY_COMMAND'], language: 'vala')
endif

use_webkit = get_option('webkit')
if use_webkit == 'auto'
  use_webkit = (host_machine.system() == 'darwin') ? 'false' : 'true'
endif
if use_webkit == 'true'
  dependencies += dependency('webkitgtk-6.0')
  add_project_arguments(['--define=WEBKIT'], language: 'vala')
endif

if get_option('latex')
  dependencies += dependency('lasem-0.6')
  extra_vala_args += join_paths(meson.project_source_root(), 'vapi', 'lasem-0.6.vapi')
  add_project_arguments(['--define=LATEX'], language: 'vala')
endif

subdir('tests')

test_executable = executable(
  'minder-regress',
  test_vala_sources,
  files(
    'src/LatexSpanParser.vala',
    'src/ImageManager.vala',
    'src/NodeImage.vala',
    'src/NodeTableModel.vala',
    'src/PixbufPainter.vala',
    'src/XmlFragment.vala',
    'src/RecentFiles.vala',
    'src/PanedGeometry.vala',
  ),
  dependencies: dependencies,
)

test(
  'minder-regress',
  test_executable,
)

e = executable('io.github.phase1geo.minder',
    sources,
    config_file,
    gresource,
    dependencies: dependencies,
    include_directories: include_directories('src'),
    link_args: mac_link_args,
    vala_args: extra_vala_args,
    install : true
)

# These helper tools are not available on every platform (e.g. macOS), and
# gnome.post_install() fails the install when a requested one is missing.
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: find_program('gtk4-update-icon-cache', 'gtk-update-icon-cache', required: false).found(),
  update_mime_database: find_program('update-mime-database', required: false).found(),
  update_desktop_database: find_program('update-desktop-database', required: false).found(),
)
