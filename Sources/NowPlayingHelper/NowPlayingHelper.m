#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include "NowPlayingHelper.h"

// Private MediaRemote.framework API, resolved at runtime.
typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef Boolean (*MRSendCommandFn)(int, CFDictionaryRef);

enum { kMRTogglePlayPause = 2, kMRNextTrack = 4, kMRPreviousTrack = 5 };

static MRGetInfoFn MRGetInfo;
static MRGetIsPlayingFn MRGetIsPlaying;
static MRGetPIDFn MRGetPID;
static MRRegisterFn MRRegister;
static MRSendCommandFn MRSendCommand;

static NSString *lastArtworkHash;

static BOOL loadMediaRemote(void) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!h) return NO;
    MRGetInfo = (MRGetInfoFn)dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
    MRGetIsPlaying = (MRGetIsPlayingFn)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    MRGetPID = (MRGetPIDFn)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationPID");
    MRRegister = (MRRegisterFn)dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
    MRSendCommand = (MRSendCommandFn)dlsym(h, "MRMediaRemoteSendCommand");
    return MRGetInfo && MRGetIsPlaying && MRGetPID && MRRegister && MRSendCommand;
}

static void emit(NSDictionary *dict) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void copyString(NSDictionary *info, NSString *key, NSMutableDictionary *out, NSString *outKey) {
    id v = info[key];
    if ([v isKindOfClass:NSString.class]) out[outKey] = v;
}

static void copyNumber(NSDictionary *info, NSString *key, NSMutableDictionary *out, NSString *outKey) {
    id v = info[key];
    if ([v isKindOfClass:NSNumber.class]) out[outKey] = v;
}

static void refresh(void) {
    dispatch_queue_t q = dispatch_get_main_queue();
    MRGetInfo(q, ^(CFDictionaryRef cfInfo) {
        NSDictionary *info = cfInfo ? [(__bridge NSDictionary *)cfInfo copy] : nil;
        MRGetIsPlaying(q, ^(Boolean playing) {
            MRGetPID(q, ^(int pid) {
                NSMutableDictionary *out = [NSMutableDictionary dictionary];
                out[@"playing"] = @(playing);
                out[@"pid"] = @(pid);
                if (info) {
                    copyString(info, @"kMRMediaRemoteNowPlayingInfoTitle", out, @"title");
                    copyString(info, @"kMRMediaRemoteNowPlayingInfoArtist", out, @"artist");
                    copyString(info, @"kMRMediaRemoteNowPlayingInfoAlbum", out, @"album");
                    copyNumber(info, @"kMRMediaRemoteNowPlayingInfoDuration", out, @"duration");
                    copyNumber(info, @"kMRMediaRemoteNowPlayingInfoElapsedTime", out, @"elapsed");
                    copyNumber(info, @"kMRMediaRemoteNowPlayingInfoPlaybackRate", out, @"rate");
                    id ts = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                    if ([ts isKindOfClass:NSDate.class]) out[@"timestamp"] = @([(NSDate *)ts timeIntervalSince1970]);

                    // Only send artwork when it changes; it can be a few hundred KB.
                    id art = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                    if ([art isKindOfClass:NSData.class] && [(NSData *)art length] > 0) {
                        NSString *hash = [NSString stringWithFormat:@"%lu-%lu",
                                          (unsigned long)[(NSData *)art length], (unsigned long)[art hash]];
                        if (![hash isEqualToString:lastArtworkHash]) {
                            lastArtworkHash = hash;
                            out[@"artwork"] = [(NSData *)art base64EncodedStringWithOptions:0];
                        }
                    } else {
                        lastArtworkHash = nil;
                        out[@"artwork"] = @"";
                    }
                } else {
                    lastArtworkHash = nil;
                }
                emit(out);
            });
        });
    });
}

static void readCommands(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        char line[256];
        while (fgets(line, sizeof line, stdin)) {
            int cmd = -1;
            if (strncmp(line, "toggle", 6) == 0) cmd = kMRTogglePlayPause;
            else if (strncmp(line, "next", 4) == 0) cmd = kMRNextTrack;
            else if (strncmp(line, "previous", 8) == 0) cmd = kMRPreviousTrack;
            if (cmd >= 0) {
                dispatch_async(dispatch_get_main_queue(), ^{ MRSendCommand(cmd, NULL); });
            }
        }
        // stdin closed: the app quit, so do we.
        exit(0);
    });
}

void np_stream(void *perl_interpreter, void *cv) {
    (void)perl_interpreter; (void)cv;
    @autoreleasepool {
        if (!loadMediaRemote()) {
            emit(@{@"error": @"MediaRemote unavailable"});
            exit(1);
        }
        MRRegister(dispatch_get_main_queue());
        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ];
        for (NSString *name in names) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil
                                                          usingBlock:^(NSNotification *note) { refresh(); }];
        }
        refresh();
        readCommands();
    }
    CFRunLoopRun();
    exit(0);
}
