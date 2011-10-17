//
//  KTPublishingWindowController.h
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTLocalPublishingEngine.h"


@class KTPublishingEngine, CKTransferRecord, UKDockProgressIndicator, SVLoginWindowController;



@interface KTPublishingWindowController : NSWindowController <KTPublishingEngineDelegate>
{
    IBOutlet NSTextField            *oMessageLabel;
    IBOutlet NSTextField            *oInformativeTextLabel;
    IBOutlet NSProgressIndicator    *oProgressIndicator;
    IBOutlet NSButton               *oFirstButton;
    IBOutlet NSButton               *oSecondButton;
    IBOutlet NSTableColumn          *oTransferDetailsTableColumn;
	IBOutlet NSButton				*oExpandButton;
    IBOutlet NSView					*oAccessoryView; // currently the scrollview around the outline
    
  @private
    KTPublishingEngine      *_publishingEngine;
    BOOL                    _didFail;
    
    NSWindow    *_modalWindow;  // Weak ref
	
	UKDockProgressIndicator *_dockProgress;
	// KSAlert
	NSString	*_messageText;
	NSString	*_informativeText;
    
    SVLoginWindowController  *_loginWindowController;
}

- (IBAction)firstButtonAction:(NSButton *)sender;
- (IBAction)secondButtonAction:(NSButton *)sender;

- (id)initWithPublishingEngine:(KTPublishingEngine *)engine;
@property(nonatomic, retain, readonly) KTPublishingEngine *publishingEngine;
- (BOOL)isExporting;

// Presentation
- (void)beginSheetModalForWindow:(NSWindow *)window;
- (void)endSheet;

- (NSView *)accessoryView;
- (IBAction)toggleExpanded:(id)sender;
- (void)showAccessoryView:(BOOL)showFlag animate:(BOOL)animateFlag;

@end


@interface KTPublishingWindowController (KSAlert)
- (NSString *)messageText;
- (void)setMessageText:(NSString *)text;
- (NSString *)informativeText;
- (void)setInformativeText:(NSString *)text;
@end

