//
//  KTTranscriptController.h
//  Marvel
//
//  Created by Dan Wood on 10/25/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"


@interface KTTranscriptController : KSSingletonWindowController {

	IBOutlet NSTextView *oLog;
}

- (NSTextStorage *)textStorage;
- (IBAction) clearTranscript:(id)sender;

@end


@interface KTTranscriptPanel : NSPanel
@end