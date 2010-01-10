//
//  SVInspectorWindowController.h
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSInspector.h"


@class KSInspectorViewController, SVLinkInspector;


@interface SVInspector : KSInspector
{
  @private
    id <KSCollectionController> _inspectedPagesController;
    
    KSInspectorViewController   *_documentInspector;
    KSInspectorViewController   *_pageInspector;
    KSInspectorViewController   *_collectionInspector;
    KSInspectorViewController   *_wrapInspector;
    SVLinkInspector             *_linkInspector;
    KSInspectorViewController   *_plugInInspector;
}

@property(nonatomic, retain) id <KSCollectionController> inspectedPagesController;

@end
