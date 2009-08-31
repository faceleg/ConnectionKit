//
//  SVDesignChooserWindowController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserWindowController.h"

#import "Debug.h"
#import "KSPlugin.h"
#import "KT.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "NSArray+Karelia.h"
#import "SVDesignChooserViewController.h"


@implementation SVDesignChooserWindowController

- (void)awakeFromNib
{
    // load the xib that contains the collection view
    viewController_ = [[SVDesignChooserViewController alloc] initWithNibName:@"SVDesignChooserCollectionView" 
                                                                      bundle:nil];

    // pop the collection view into the window
    [oTargetView addSubview:[viewController_ view]];
    
    // make sure we resize the viewController's view to match its superview
    [[viewController_ view] setFrame:[oTargetView bounds]];
}

- (void)displayAsSheet
{
    [NSApp beginSheet:[self window]
       modalForWindow:[[(KTDocument *)[self document] mainWindowController] window]
        modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
          contextInfo:nil];
    
    [self bind:@"selectedDesign"
      toObject:[[[self document] mainWindowController] siteOutlineController]
   withKeyPath:@"selection.master.design"
       options:nil];    
}

- (IBAction)chooseDesign:(id)sender
{
    // get the selected design
    NSUInteger selectedIndex = [[viewController_ designsArrayController] selectionIndex];
    KTDesign *design = [[viewController_ designs] objectAtIndex:selectedIndex];
    OBASSERT(nil != design);
    
    // prep the design
    [design loadLocalFontsIfNeeded];
    
    // message the document to change its design
    // (by telling the KTDocSiteOutlineController to update its selection.master.design)
    NSDictionary *bindingsInfo = [self infoForBinding:@"selectedDesign"];
    id controller = [bindingsInfo objectForKey:NSObservedObjectKey];
    NSString *keyPath = [bindingsInfo objectForKey:NSObservedKeyPathKey];
    [controller setValue:design forKeyPath:keyPath];
    
    // notify observers ?
    // FIXME: webview needs to actually update/redraw
    // here's the old notification code that the new SVWeb classes don't observe
//    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                              [NSNumber numberWithBool:YES], @"animate",
//                              NSStringFromPoint(NSMakePoint(0, 0)), @"mouse",
//                              nil];
//    [[NSNotificationCenter defaultCenter] postNotificationName:kKTDesignChangedNotification
//                                                        object:[self document]
//                                                      userInfo:userInfo];
    
    // close up shop, we're done
    [NSApp endSheet:[self window]];    
}

- (IBAction)cancelSheet:(id)sender
{
    [NSApp endSheet:[self window]];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    OBASSERT(sheet == [self window]);
    [sheet orderOut:self];
    
    [self unbind:@"selectedDesign"];
}

@synthesize selectedDesign = selectedDesign_;
- (void)setSelectedDesign:(KTDesign *)aDesign
{
    [aDesign retain];
    [selectedDesign_ release];
    selectedDesign_ = aDesign;
    
    (void)[[viewController_ designsArrayController] setSelectedObjects:[NSArray arrayWithObject:selectedDesign_]];
}

@synthesize viewController = viewController_;
@end
