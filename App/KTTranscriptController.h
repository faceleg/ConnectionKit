//
//  KTTranscriptController.h
//  Marvel
//
//  Created by Dan Wood on 10/25/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@protocol NSTextStorageDelegate <NSObject> @end
#endif

@interface KTTranscriptController : KSSingletonWindowController <NSTextStorageDelegate>
{
	IBOutlet NSTextView *oLog;
}

- (NSTextStorage *)textStorage;
- (IBAction) clearTranscript:(id)sender;

@end


@interface KTTranscriptPanel : NSPanel
@end