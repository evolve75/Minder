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

public delegate void VoidFunc();

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
  private static int FRAMES = 20;   // MINDER_BENCH_FRAMES overrides, for profiling
  private static string? _scratch = null;

  //-------------------------------------------------------------
  // A private folder for the scratch files, so that the file names
  // cannot be pre-created by another user of a shared temp folder.
  private static string scratch_dir() {
    if( _scratch == null ) {
      try {
        _scratch = DirUtils.make_tmp( "minder-bench-XXXXXX" );
      } catch( FileError e ) {
        _scratch = Environment.get_tmp_dir();
      }
    }
    return( _scratch );
  }

  //-------------------------------------------------------------
  // Runs all scenarios on the current tab and prints the results.
  public static void run( MainWindow win, owned VoidFunc done ) {

    var frames = Environment.get_variable( "MINDER_BENCH_FRAMES" );
    if( frames != null ) {
      FRAMES = int.parse( frames );
    }

    var map = win.get_current_map();
    if( map == null ) {
      stderr.printf( "benchmark: no map is open\n" );
      done();
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

    time_save( map );
    time_images();
    time_text_helpers();

    check_culling( map, 1.0 );
    check_culling( map, 0.1 );
    check_latex_clip( map, 1.0 );
    check_latex_clip( map, 0.5 );

    if( Environment.get_variable( "MINDER_BENCH_CHURN" ) != null ) {
      Idle.add(() => { time_tab_churn( win, map, (owned) done ); return( Source.REMOVE ); });
    } else {
      time_animation( map, (owned) done );
    }

  }

  //-------------------------------------------------------------
  // Times a full save of the document (the work a recovery copy also does).
  // The document is pointed at a temporary file first, so the file the map was
  // loaded from is never written.
  private static void time_save( MindMap map ) {
    var scratch = GLib.Path.build_filename( scratch_dir(), "minder-bench-%d.minder".printf( (int)GLib.get_monotonic_time() ) );
    map.doc.filename = scratch;
    var times = new double[3];
    for( int i=0; i<3; i++ ) {
      var start = GLib.get_monotonic_time();
      map.doc.save( true, true );
      times[i] = (GLib.get_monotonic_time() - start) / 1000.0;
    }
    FileUtils.unlink( scratch );
    FileUtils.unlink( GLib.Path.build_filename( scratch_dir(), "." + GLib.Path.get_basename( scratch ) + ".bak" ) );
    stdout.printf( "BENCH save per call: %.1f ms, %.1f ms, %.1f ms\n", times[0], times[1], times[2] );
  }

  //-------------------------------------------------------------
  // Times painting a 300x200 raster image: rebuilding the Cairo surface on
  // every draw (the old way) against the cached surface.
  private static void time_images() {

    var pixbuf  = new Gdk.Pixbuf( Gdk.Colorspace.RGB, true, 8, 300, 200 );
    pixbuf.fill( 0x3080c0ff );
    var surface = new ImageSurface( Format.ARGB32, 1600, 1000 );
    var painter = new PixbufPainter();
    const int DRAWS = 2000;

    var start = GLib.get_monotonic_time();
    for( int i=0; i<DRAWS; i++ ) {
      var ctx = new Context( surface );
      Gdk.cairo_set_source_pixbuf( ctx, pixbuf, (i % 50), 10 );
      ctx.paint_with_alpha( 1.0 );
    }
    var old_ms = (GLib.get_monotonic_time() - start) / 1000.0;

    start = GLib.get_monotonic_time();
    for( int i=0; i<DRAWS; i++ ) {
      painter.paint( new Context( surface ), pixbuf, (i % 50), 10, 1.0 );
    }
    var new_ms = (GLib.get_monotonic_time() - start) / 1000.0;

    stdout.printf( "BENCH image-draw per-draw: rebuild=%.3f ms  cached=%.3f ms  (%d draws, 300x200)\n",
                   old_ms / DRAWS, new_ms / DRAWS, DRAWS );

  }

  //-------------------------------------------------------------
  // Times the text helpers that run on every search keystroke, word jump and
  // note tooltip.
  private static void time_text_helpers() {

    const int CALLS = 2000;
    var note = "A **bold** note with `code`, a [link](http://example.com) and\n\n* one\n* two\n* ==marked==\n";
    var text = "the quick brown fox jumps over the lazy dog";

    stdout.printf( "BENCH text-helpers sample: remove_markdown='%s' markup='%s' find_word=%d\n",
                   Utils.remove_markdown( note ).replace( "\n", "|" ),
                   Utils.prepare_note_markup( note ).replace( "\n", "|" ), Utils.find_word( text, 20, true ) );

    var start = GLib.get_monotonic_time();
    for( int i=0; i<CALLS; i++ ) {
      Utils.remove_markdown( note );
    }
    var remove_ms = (GLib.get_monotonic_time() - start) / 1000.0 / CALLS;

    start = GLib.get_monotonic_time();
    for( int i=0; i<CALLS; i++ ) {
      Utils.prepare_note_markup( note );
    }
    var tooltip_ms = (GLib.get_monotonic_time() - start) / 1000.0 / CALLS;

    start = GLib.get_monotonic_time();
    for( int i=0; i<CALLS; i++ ) {
      Utils.find_word( text, 20, true );
      Utils.find_word( text, 20, false );
    }
    var word_ms = (GLib.get_monotonic_time() - start) / 1000.0 / CALLS;

    stdout.printf( "BENCH text-helpers per call: remove_markdown=%.4f ms  prepare_note_markup=%.4f ms  find_word(x2)=%.4f ms\n",
                   remove_ms, tooltip_ms, word_ms );

  }

  //-------------------------------------------------------------
  // Draws one frame with and without off-screen culling and reports whether the
  // pixels are identical.
  private static void check_culling( MindMap map, double map_scale ) {

    var orig_scale = map.canvas.sfactor;
    map.canvas.sfactor = map_scale;
    var paths = new string[] {
      GLib.Path.build_filename( scratch_dir(), "minder-bench-culled-%g.png".printf( map_scale ) ),
      GLib.Path.build_filename( scratch_dir(), "minder-bench-full-%g.png".printf( map_scale ) )
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
  // Resident memory of this process in kilobytes.
  private static int64 rss_kb() {
    try {
      string output;
      Process.spawn_command_line_sync( "ps -o rss= -p %d".printf( (int)Posix.getpid() ), out output );
      return( int64.parse( output.strip() ) );
    } catch( SpawnError e ) {
      return( -1 );
    }
  }

  //-------------------------------------------------------------
  // Opens and closes copies of the current map repeatedly and reports how the
  // process's memory changes, to find tabs that are never freed.
  // MINDER_BENCH_ROUNDS sets the number of rounds, MINDER_BENCH_HOLD keeps the
  // process alive that many seconds afterwards for a profiler.
  private static void time_tab_churn( MainWindow win, MindMap map, owned VoidFunc done ) {

    var rounds_env    = Environment.get_variable( "MINDER_BENCH_ROUNDS" );
    int ROUNDS        = (rounds_env != null) ? int.parse( rounds_env ) : 40;
    int WARMUP_ROUNDS = 5;
    var dir       = scratch_dir();
    var first     = map.doc.filename;
    var iter      = 0;
    var base_rss  = 0LL;
    var start_rss = rss_kb();

    Timeout.add( 150, () => {
      if( iter > 0 ) {
        win.close_current_tab();
      }
      if( iter == ROUNDS ) {
        var end_rss = rss_kb();
        stdout.printf( "BENCH tab-churn: start=%lld KB after-warmup=%lld KB end=%lld KB  growth over %d open/close rounds=%lld KB (%.0f KB per round)\n",
                       start_rss, base_rss, end_rss, ROUNDS - WARMUP_ROUNDS, end_rss - base_rss,
                       (double)(end_rss - base_rss) / (ROUNDS - WARMUP_ROUNDS) );
        var hold = Environment.get_variable( "MINDER_BENCH_HOLD" );
        if( hold != null ) {
          stdout.printf( "BENCH holding for %s s, pid=%d\n", hold, (int)Posix.getpid() );
          stdout.flush();
          Timeout.add_seconds( int.parse( hold ), () => { done(); return( Source.REMOVE ); } );
        } else {
          done();
        }
        return( Source.REMOVE );
      }
      var copy = GLib.Path.build_filename( dir, "minder-churn-%d.minder".printf( iter ) );
      var src  = File.new_for_path( first );
      try {
        src.copy( File.new_for_path( copy ), FileCopyFlags.OVERWRITE );
      } catch( Error e ) {
        stderr.printf( "benchmark: %s\n", e.message );
      }
      win.open_file( copy, false );
      iter++;
      if( iter == WARMUP_ROUNDS ) {
        base_rss = rss_kb();
      }
      return( Source.CONTINUE );
    });

  }

  //-------------------------------------------------------------
  // Runs a zoom-to-fit animation and reports how many frames were drawn and how
  // long it took, according to the display's frame clock.
  private static void time_animation( MindMap map, owned VoidFunc done ) {

    var canvas = map.canvas;
    var frames = 0;
    int64 first = -1;
    int64 last  = 0;
    var seen_running = false;
    canvas.zoom_to_fit();
    canvas.add_tick_callback( (w, clock) => {
      var now = clock.get_frame_time();
      if( first < 0 ) first = now;
      last = now;
      frames++;
      if( canvas.animator.is_running() ) {
        seen_running = true;
      } else if( seen_running || (frames > 120) ) {
        stdout.printf( "BENCH animation zoom-to-fit: frames=%d duration=%.0f ms\n", frames, (last - first) / 1000.0 );
        done();
        return( Source.REMOVE );
      }
      return( Source.CONTINUE );
    });

  }

  //-------------------------------------------------------------
  // Draws one frame with the formula mask clipped and unclipped and reports
  // whether the pixels are identical.
  private static void check_latex_clip( MindMap map, double map_scale ) {

    var orig_scale = map.canvas.sfactor;
    map.canvas.sfactor = map_scale;
    var paths = new string[] {
      GLib.Path.build_filename( scratch_dir(), "minder-bench-clip-%g.png".printf( map_scale ) ),
      GLib.Path.build_filename( scratch_dir(), "minder-bench-noclip-%g.png".printf( map_scale ) )
    };
    for( int pass=0; pass<2; pass++ ) {
      LatexRenderer.clip_mask = (pass == 0);
      var surface = new ImageSurface( Format.ARGB32, 1600, 1000 );
      map.canvas.on_draw( map.canvas, new Context( surface ), 1600, 1000 );
      surface.write_to_png( paths[pass] );
    }
    LatexRenderer.clip_mask = true;
    map.canvas.sfactor      = orig_scale;

    var differing = 0;
    var size      = 0;
    try {
      uint8[] a, b;
      FileUtils.get_data( paths[0], out a );
      FileUtils.get_data( paths[1], out b );
      differing = (a.length != b.length) ? -1 : (Memory.cmp( a, b, a.length ) == 0 ? 0 : 1);
      size      = a.length;
    } catch( FileError e ) {
      differing = -2;
    }
    stdout.printf( "BENCH latex-clip-identical scale=%g differing=%d (0 means identical) png-bytes=%d\n", map_scale, differing, size );

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
