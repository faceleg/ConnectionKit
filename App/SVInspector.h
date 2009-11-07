//
//  SVInspectorWindowController.h
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSInspector.h"


@class SVInspectorViewController;


@interface SVInspector : KSInspector
{
  @private
    NSObjectController  *_inspectedPagesController;
    
    SVInspectorViewController   *_documentInspector;
    SVInspectorViewController   *_pageInspector;
    SVInspectorViewController   *_wrapInspector;
}

@property(nonatomic, retain) NSObjectController *inspectedPagesController;

@end
