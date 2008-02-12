//
//  KTPlaceholderController.m
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTPlaceholderController.h"

static KTPlaceholderController *sSharedPlaceholderController = nil;

@implementation KTPlaceholderController

+ (KTPlaceholderController *)sharedPlaceholderController;
{
    if ( nil == sSharedPlaceholderController ) {
        sSharedPlaceholderController = [[self alloc] init];
    }
    return sSharedPlaceholderController;
}

+ (KTPlaceholderController *)sharedPlaceholderControllerWithoutLoading;
{
	return sSharedPlaceholderController;
}

- (id)init
{
    self = [super initWithWindowNibName:@"Placeholder"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[[self window] center];
	[[self window] setLevel:NSNormalWindowLevel];
	[[self window] setExcludedFromWindowsMenu:YES];
}


- (IBAction) doNew:(id)sender
{
	[[self window] orderOut:self];
	[[NSApp delegate] newDocument:nil];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
						   withObject:nil
						   afterDelay:0.0];
}

- (IBAction) doOpen:(id)sender
{
	[[self window] orderOut:self];
	[[NSDocumentController sharedDocumentController] openDocument:self];

	[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
			   withObject:nil
			   afterDelay:0.0];
	
}

@end
