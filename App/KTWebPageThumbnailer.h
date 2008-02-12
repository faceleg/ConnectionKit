//
//  KTWebPageThumbnailer.h
//  Marvel
//
//  Created by Greg Hulands on 24/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
		This is not thread safe so if using in background threads, make sure
		you instantiate your own instance instead of using the shared one.
 */

@interface KTWebPageThumbnailer : NSObject 
{
	NSWindow		*myWindow;
	WebView			*myWebView;
	NSURLRequest	*myCurrentRequest;
	
	NSLock			*myLock;
	NSPort			*myPort;
	NSThread		*myWorkerThread;
	NSMutableArray	*myJobQueue;
}

+ (id)sharedThumbnailer;

- (id)init;

// sync
- (NSImage *)thumbnailForURL:(NSURL *)url size:(NSSize)size;

// async
- (void)fetchThumbnailForURL:(NSURL *)url notifyTarget:(id)target size:(NSSize)size;

@end

@interface NSObject (KTWebPageThumbnailerInformalProtocol)
- (void)thumbnailer:(KTWebPageThumbnailer *)nailer hasThumbnail:(NSImage *)thumb forURL:(NSURL *)url;
@end
