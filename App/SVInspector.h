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
    id <KSCollectionController> _inspectedPagesController;
    
    SVInspectorViewController   *_documentInspector;
    SVInspectorViewController   *_pageInspector;
    SVInspectorViewController   *_wrapInspector;
}

@property(nonatomic, retain) id <KSCollectionController> inspectedPagesController;

@end
