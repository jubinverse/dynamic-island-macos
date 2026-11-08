#pragma once

/// Entry point installed as a Perl XSUB by NowPlayingMonitor.loaderScript.
/// Streams now-playing state to stdout as one JSON object per line, and reads
/// commands ("toggle", "next", "previous") from stdin. Never returns.
///
/// Why Perl: since macOS 15.4, mediaremoted only answers processes whose bundle
/// identifier is Apple's. /usr/bin/perl qualifies, so we run this code inside it.
void np_stream(void *perl_interpreter, void *cv);
