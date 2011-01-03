//
//  KTAcknowledgmentsController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/6/06.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "KTAcknowledgmentsController.h"


@implementation KTAcknowledgmentsController

/*
+ (id)sharedController;
{
    static id sSharedController = nil;
    if ( nil == sSharedController ) 
    {
        sSharedController = [[self alloc] init];
    }
    
    return sSharedController;
}
*/

- (void)windowDidLoad
{
    // load Acknowledgments.rtf
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Acknowledgments" ofType:@"rtf"];
    (void)[oTextView readRTFDFromFile:path];
    [[self window] setTitle:NSLocalizedString(@"Sandvox Acknowledgments", "Acknowledgments Window Title")];
    [[self window] setFrameAutosaveName:@"AcknowledgmentsWindow"];    
}

@end
