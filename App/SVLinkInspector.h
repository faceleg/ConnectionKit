//
//  SVLinkInspector.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "KTLinkSourceView.h"

#import <WebKit/WebKit.h>


typedef enum {
    SVLinkNone,
    SVLinkToPage,
    SVLinkToRSSFeed,
    SVLinkToFullSizeImage = 8,
    SVLinkExternal = 10,
} SVLinkType;


@class SVLink;


@interface SVLinkInspector : KSInspectorViewController <KTLinkSourceViewDelegate>
{
    IBOutlet NSPopUpButton      *oLinkTypePopUpButton;
    IBOutlet NSTabView          *oTabView;
    
    IBOutlet KTLinkSourceView   *oLinkSourceView;
    IBOutlet NSTextField        *oLinkField;
    IBOutlet NSButton           *oOpenInNewWindowCheckbox;
    
  @private
}


#pragma mark UI Actions

- (IBAction)selectLinkType:(NSPopUpButton *)sender;

- (IBAction)setLinkURL:(id)sender;
- (IBAction)clearLinkDestination:(id)sender;

@end