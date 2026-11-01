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

#import <Cocoa/Cocoa.h>
#import <PDFKit/PDFKit.h>
#include <gdk/macos/gdkmacos.h>

#include "macos-print.h"

/* Keeps the user's choices (paper, orientation, copies, duplex, ...) between
 * print jobs in one session. */
static NSPrintInfo *shared_print_info (void)
{
  static NSPrintInfo *info = nil;
  if (info == nil)
    {
      info = [[NSPrintInfo sharedPrintInfo] copy];
      [info setHorizontalPagination: NSPrintingPaginationModeFit];
      [info setVerticalPagination:   NSPrintingPaginationModeFit];
      [info setHorizontallyCentered: YES];
      [info setVerticallyCentered:   YES];
    }
  return info;
}

/* Retains the document until the sheet closes */
@interface MinderPrintDelegate : NSObject
@property (strong) PDFDocument *document;
@end

static NSMutableSet *live_delegates = nil;

@implementation MinderPrintDelegate
- (void) printOperationDidRun: (NSPrintOperation *) op success: (BOOL) success contextInfo: (void *) info
{
  (void) op; (void) success; (void) info;
  [live_delegates removeObject: self];
}
@end

static NSPrintOperation *make_operation (NSString *path, NSString *title, PDFDocument **doc_out)
{
  PDFDocument *doc = [[PDFDocument alloc] initWithURL: [NSURL fileURLWithPath: path]];
  if (doc == nil || [doc pageCount] == 0)
    return nil;

  /* Fit the page to the chosen paper; rotate it when that gives a larger image */
  NSPrintOperation *op = [doc printOperationForPrintInfo: shared_print_info ()
                                             scalingMode: kPDFPrintPageScaleToFit
                                              autoRotate: YES];
  [op setJobTitle: title];
  *doc_out = doc;
  return op;
}

gboolean
minder_macos_print_pdf (GtkWindow *parent, const char *pdf_path, const char *job_name)
{
  @autoreleasepool
    {
      GtkNative  *native  = GTK_NATIVE (parent);
      GdkSurface *surface = (native != NULL) ? gtk_native_get_surface (native) : NULL;
      if (surface == NULL || !GDK_IS_MACOS_SURFACE (surface))
        return FALSE;

      NSWindow *window = (__bridge NSWindow *) gdk_macos_surface_get_native_window (GDK_MACOS_SURFACE (surface));
      if (window == nil)
        return FALSE;

      PDFDocument *doc = nil;
      NSPrintOperation *op = make_operation ([NSString stringWithUTF8String: pdf_path],
                                             [NSString stringWithUTF8String: job_name], &doc);
      if (op == nil)
        return FALSE;

      [op setShowsPrintPanel: YES];
      [op setShowsProgressPanel: YES];

      /* The default panel hides paper size and orientation (they normally live
         in Page Setup, which this app does not offer). */
      NSPrintPanel *panel = [op printPanel];
      [panel setOptions: [panel options] | NSPrintPanelShowsPaperSize
                                         | NSPrintPanelShowsOrientation
                                         | NSPrintPanelShowsScaling];

      if (live_delegates == nil)
        live_delegates = [[NSMutableSet alloc] init];
      MinderPrintDelegate *delegate = [[MinderPrintDelegate alloc] init];
      delegate.document = doc;
      [live_delegates addObject: delegate];

      [op runOperationModalForWindow: window
                            delegate: delegate
                      didRunSelector: @selector (printOperationDidRun:success:contextInfo:)
                         contextInfo: NULL];
      return TRUE;
    }
}

gboolean
minder_macos_print_pdf_to_file (const char *pdf_path, const char *save_path)
{
  @autoreleasepool
    {
      PDFDocument *doc = nil;
      NSPrintOperation *op = make_operation ([NSString stringWithUTF8String: pdf_path], @"Minder", &doc);
      if (op == nil)
        return FALSE;

      NSPrintInfo *info = [op printInfo];
      [info setJobDisposition: NSPrintSaveJob];
      [[info dictionary] setObject: [NSURL fileURLWithPath: [NSString stringWithUTF8String: save_path]]
                            forKey: NSPrintJobSavingURL];
      [op setShowsPrintPanel: NO];
      [op setShowsProgressPanel: NO];
      return [op runOperation];
    }
}
