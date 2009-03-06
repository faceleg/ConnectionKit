//
//  KTTranscriptController.m
//  Marvel
//
//  Created by Dan Wood on 10/25/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTTranscriptController.h"

#import "NSObject+Karelia.h"


@implementation KTTranscriptController

- (NSTextStorage *)textStorage
{
	return [oLog textStorage];
}

- (id)init
{
    self = [super initWithWindowNibName:@"KTTranscript"];
    return self;
}

- (void)windowDidLoad
{
    
    [super windowDidLoad];
	
	[[self window] setTitle:NSLocalizedString(@"Publishing Transcript", "window title")];
	[[self window] setFrameAutosaveName:@"transcript"];
    
	NSTextStorage *textStorage = [oLog textStorage];
	[textStorage setDelegate:self];		// get notified when text changes
}

/*!	Called as a delegate of the log's text storage, so we can update the scroll position
*/
- (void)textStorageDidProcessEditing:(NSNotification *)aNotification
{
	[self performSelector:@selector(scrollToVisible:) withObject:nil afterDelay:0.0];
	// Don't scroll now, do it in a moment. Doing it now causes error messgaes.
}

- (void) scrollToVisible:(id)unused
{
	[oLog scrollRangeToVisible:NSMakeRange([[oLog textStorage] length], 0)];
}

- (IBAction) clearTranscript:(id)sender
{
	[[self textStorage] deleteCharactersInRange:NSMakeRange(0,[[oLog textStorage] length])];
	[self scrollToVisible:nil];
}



@end
