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

using Cairo;

/*
 * Times the canvas drawing code on the loaded map, for the performance work
 * tracked in the M6 milestone.  Run with:  minder --benchmark map.minder
 *
 * Each scenario draws the map into an offscreen surface several times and
 * reports the mean and best time per frame:
 *   viewport  - a 1600x1000 window at scale 1 (most of a large map is off-screen)
 *   hidpi     - the same at device scale 2
 *   zoom-out  - scale 0.1 so the whole map is visible (worst case)
 */
public class Benchmark {

  private const int WARMUP = 2;
  private const int FRAMES = 20;

  //-------------------------------------------------------------
  // Runs all scenarios on the current tab and prints the results.
  public static void run( MainWindow win ) {

    var map = win.get_current_map();
    if( map == null ) {
      stderr.printf( "benchmark: no map is open\n" );
      return;
    }

    var nodes = map.model.get_nodes();
    var count = 0;
    for( int i=0; i<nodes.length; i++ ) {
      count += 1 + nodes.index( i ).descendant_count();
    }
    stdout.printf( "BENCH nodes=%d\n", count );

    time_scenario( map, "viewport", 1600, 1000, 1.0, 1.0 );
    time_scenario( map, "hidpi",    1600, 1000, 2.0, 1.0 );
    time_scenario( map, "zoom-out", 1600, 1000, 1.0, 0.1 );

    check_culling( map, 1.0 );
    check_culling( map, 0.1 );

  }

  //-------------------------------------------------------------
  // Draws one frame with and without off-screen culling and reports whether the
  // pixels are identical.
  private static void check_culling( MindMap map, double map_scale ) {

    var orig_scale = map.canvas.sfactor;
    map.canvas.sfactor = map_scale;
    var paths = new string[] {
      GLib.Path.build_filename( Environment.get_tmp_dir(), "minder-bench-culled-%g.png".printf( map_scale ) ),
      GLib.Path.build_filename( Environment.get_tmp_dir(), "minder-bench-full-%g.png".printf( map_scale ) )
    };
    for( int pass=0; pass<2; pass++ ) {
      Node.cull_offscreen = (pass == 0);
      var surface = new ImageSurface( Format.ARGB32, 1600, 1000 );
      map.canvas.on_draw( map.canvas, new Context( surface ), 1600, 1000 );
      surface.write_to_png( paths[pass] );
    }
    Node.cull_offscreen = true;
    map.canvas.sfactor  = orig_scale;

    var differing = 0;
    var drawn     = 0;
    try {
      uint8[] a, b;
      FileUtils.get_data( paths[0], out a );
      FileUtils.get_data( paths[1], out b );
      differing = (a.length != b.length) ? -1 : (Memory.cmp( a, b, a.length ) == 0 ? 0 : 1);
      drawn     = a.length;
    } catch( FileError e ) {
      differing = -2;
    }
    stdout.printf( "BENCH culling-identical scale=%g differing=%d (0 means identical) png-bytes=%d  %s\n", map_scale, differing, drawn, paths[0] );

  }

  //-------------------------------------------------------------
  // Draws the map FRAMES times and prints the timing.
  private static void time_scenario( MindMap map, string name, int width, int height, double device_scale, double map_scale ) {

    var surface = new ImageSurface( Format.ARGB32, (int)(width * device_scale), (int)(height * device_scale) );
    surface.set_device_scale( device_scale, device_scale );
    var orig_scale = map.canvas.sfactor;
    map.canvas.sfactor = map_scale;

    var best  = double.MAX;
    var total = 0.0;
    for( int i=0; i<(WARMUP + FRAMES); i++ ) {
      var ctx   = new Context( surface );
      var start = GLib.get_monotonic_time();
      map.canvas.on_draw( map.canvas, ctx, width, height );
      surface.flush();
      var ms = (GLib.get_monotonic_time() - start) / 1000.0;
      if( i >= WARMUP ) {
        total += ms;
        best   = double.min( best, ms );
      }
    }

    map.canvas.sfactor = orig_scale;
    stdout.printf( "BENCH %-9s mean=%7.2f ms  best=%7.2f ms\n", name, total / FRAMES, best );

  }

}
