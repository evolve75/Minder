/*
 * Copyright (C) 2026 Anupam Sengupta <anupamsg@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Anupam Sengupta <anupamsg@gmail.com>
 */

/*
 * Main executable of Minder.app.  Points GLib and GTK at the data inside the
 * bundle, then replaces itself with the real binary.  A Mach-O launcher (instead
 * of a shell script) keeps the bundle signable and notarizable.
 */

#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define REAL_BINARY "io.github.phase1geo.minder"

static void
set_env_path (const char *name, const char *fmt, const char *base)
{
  char value[PATH_MAX * 2];
  snprintf (value, sizeof (value), fmt, base);
  setenv (name, value, 1);
}

/* The pixbuf loader cache holds absolute paths, so the bundle ships a template
 * with an @RES@ placeholder that is expanded for the bundle's current location. */
static int
write_loader_cache (const char *res, const char *cache_file)
{
  char   template_path[PATH_MAX * 2];
  FILE  *in;
  FILE  *out;
  char   line[PATH_MAX * 2];
  char   tmp_file[PATH_MAX * 2];
  int    fd;
  size_t res_len = strlen (res);

  snprintf (template_path, sizeof (template_path),
            "%s/lib/gdk-pixbuf-2.0/loaders.cache.in", res);

  in = fopen (template_path, "r");
  if (in == NULL)
    return -1;

  /* Write a fresh file next to the cache and rename it into place, so a
   * symlink planted at the cache path is replaced rather than followed. */
  snprintf (tmp_file, sizeof (tmp_file), "%s.%d", cache_file, (int) getpid ());
  unlink (tmp_file);
  fd = open (tmp_file, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
  out = (fd >= 0) ? fdopen (fd, "w") : NULL;
  if (out == NULL)
    {
      if (fd >= 0)
        close (fd);
      fclose (in);
      return -1;
    }

  while (fgets (line, sizeof (line), in) != NULL)
    {
      char *at = strstr (line, "@RES@");
      if (at != NULL)
        {
          fwrite (line, 1, (size_t) (at - line), out);
          fwrite (res, 1, res_len, out);
          fputs (at + strlen ("@RES@"), out);
        }
      else
        {
          fputs (line, out);
        }
    }

  fclose (in);
  if (fclose (out) != 0 || rename (tmp_file, cache_file) != 0)
    {
      unlink (tmp_file);
      return -1;
    }
  return 0;
}

int
main (int argc, char **argv)
{
  char        exe[PATH_MAX];
  char        real[PATH_MAX];
  char        dir[PATH_MAX];
  char        res[PATH_MAX];
  char        target[PATH_MAX];
  char        cache_dir[PATH_MAX];
  char        cache_file[PATH_MAX];
  const char *home;
  const char *xdg_cache;
  uint32_t    size = sizeof (exe);

  (void) argc;

  if (_NSGetExecutablePath (exe, &size) != 0 || realpath (exe, real) == NULL)
    return 1;

  snprintf (dir, sizeof (dir), "%s", dirname (real));
  snprintf (target, sizeof (target), "%s/../Resources", dir);
  if (realpath (target, res) == NULL)
    return 1;

  set_env_path ("XDG_DATA_DIRS",         "%s/share",                    res);
  set_env_path ("GSETTINGS_SCHEMA_DIR",  "%s/share/glib-2.0/schemas",   res);

  home      = getenv ("HOME");
  xdg_cache = getenv ("XDG_CACHE_HOME");
  if (xdg_cache != NULL && xdg_cache[0] != '\0')
    snprintf (cache_dir, sizeof (cache_dir), "%s/minder", xdg_cache);
  else
    snprintf (cache_dir, sizeof (cache_dir), "%s/.cache/minder", home != NULL ? home : "/tmp");

  {
    char parent[PATH_MAX];
    snprintf (parent, sizeof (parent), "%s", cache_dir);
    mkdir (dirname (parent), 0755);
    mkdir (cache_dir, 0755);
  }

  snprintf (cache_file, sizeof (cache_file), "%s/loaders.cache", cache_dir);
  if (write_loader_cache (res, cache_file) == 0)
    setenv ("GDK_PIXBUF_MODULE_FILE", cache_file, 1);

  snprintf (target, sizeof (target), "%s/%s", dir, REAL_BINARY);
  argv[0] = target;
  execv (target, argv);
  perror ("Minder: unable to start");
  return 1;
}
