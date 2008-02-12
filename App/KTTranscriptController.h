//
//  KTTranscriptController.h
//  Marvel
//
//  Created by Dan Wood on 10/25/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTTranscriptController : NSWindowController {

	IBOutlet NSTextView *oLog;
}

+ (KTTranscriptController *)sharedTranscriptController;
+ (KTTranscriptController *)sharedTranscriptControllerWithoutLoading;
- (NSTextStorage *)textStorage;
- (IBAction) clearTranscript:(id)sender;

@end
