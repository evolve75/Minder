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
 * Native macOS print panel for a PDF file.  GTK's macOS build has no CUPS print
 * backend, so its own dialog cannot reach a printer; this hands the PDF to
 * AppKit's print system instead.
 */

#ifndef MINDER_MACOS_PRINT_H
#define MINDER_MACOS_PRINT_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

/* Shows the print panel as a sheet on the given window.  Returns FALSE if the
 * PDF cannot be loaded or the window has no native counterpart. */
gboolean minder_macos_print_pdf (GtkWindow *parent, const char *pdf_path, const char *job_name);

/* Runs the print job without any panel and saves the result to save_path.  Used
 * to check the PDF -> AppKit printing pipeline without user interaction. */
gboolean minder_macos_print_pdf_to_file (const char *pdf_path, const char *save_path);

G_END_DECLS

#endif /* MINDER_MACOS_PRINT_H */
