//
//  KTDocWindowController+ModalOperation.m
//  Marvel
//
//  Created by Greg Hulands on 14/12/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDocWindowController.h"
#import "KTApplication.h"

@implementation KTDocWindowController (ModalOperation)

- (void)beginSheetWithStatus:(NSString *)status image:(NSImage *)image
{
	if (status != nil)
		[oModalStatus setStringValue:status];
	else 
		[oModalStatus setStringValue:@""];
	
	if (image == nil)
		[oModalImage setImage:[[KTApplication sharedApplication] applicationIconImage]];
	else
		[oModalImage setImage:image];
	
	[oModalProgress setIndeterminate:YES];
	[oModalProgress setUsesThreadedAnimation:YES];
	[oModalProgress startAnimation:nil];
	[[KTApplication sharedApplication] beginSheet:oModalPanel
								   modalForWindow:[self window]
									modalDelegate:nil
								   didEndSelector:NULL
									  contextInfo:nil];
	[NSApp cancelUserAttentionRequest:NSCriticalRequest];
}

- (void)beginSheetWithStatus:(NSString *)status minValue:(double)min maxValue:(double)max image:(NSImage *)image
{
	if (status != nil)
		[oModalStatus setStringValue:status];
	else 
		[oModalStatus setStringValue:@""];
	
	if (image == nil)
		[oModalImage setImage:[[KTApplication sharedApplication] applicationIconImage]];
	else
		[oModalImage setImage:image];
	
	[oModalProgress setIndeterminate:NO];
	[oModalProgress setUsesThreadedAnimation:YES];
	[oModalProgress setMinValue:min];
	[oModalProgress setMaxValue:max];
	[[KTApplication sharedApplication] beginSheet:oModalPanel
								   modalForWindow:[self window]
									modalDelegate:nil
								   didEndSelector:NULL
									  contextInfo:nil];
	[NSApp cancelUserAttentionRequest:NSCriticalRequest];
}

- (void)updateSheetWithStatus:(NSString *)status progressValue:(double)value
{
	if ( nil != status )
	{
		[oModalStatus setStringValue:status];
	}
	else 
	{
		[oModalStatus setStringValue:@""];
	}
	[oModalProgress setDoubleValue:value];
	
	[oModalStatus setNeedsDisplay:YES]; [oModalStatus display];
	[oModalProgress setNeedsDisplay:YES]; [oModalProgress display];
}

- (void)endSheet
{
	[[KTApplication sharedApplication] endSheet:oModalPanel];
	[oModalPanel orderOut:nil];
	[oModalProgress stopAnimation:nil];
}

- (void)setSheetMinValue:(double)min maxValue:(double)max
{
	[oModalProgress setMinValue:min];
	[oModalProgress setMaxValue:max];
}

@end