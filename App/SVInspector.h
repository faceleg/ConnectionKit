//
//  SVInspectorWindowController.h
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "KSInspector.h"


@class KSInspectorViewController, SVWrapInspector, SVLinkInspector, SVPlugInInspector;


@interface SVInspector : KSInspector
{
  @private    
    KSInspectorViewController   *_documentInspector;
    KSInspectorViewController   *_pageInspector;
    KSInspectorViewController   *_collectionInspector;
    SVWrapInspector             *_wrapInspector;
    //KSInspectorViewController   *_graphicInspector;
    KSInspectorViewController   *_metricsInspector;
    SVLinkInspector             *_linkInspector;
    SVPlugInInspector           *_plugInInspector;
}

@property(nonatomic, retain, readonly) SVLinkInspector *linkInspector;

@end
