//
//  SVInspectorViewController.h
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "KSInspectorTabsController.h"


@class KTDocument;


@interface SVInspectorViewController : KSInspectorViewController <KSInspectorViewController>
{
  @private  // TODO: Enough spare ivars for later changes without breaking plug-ins
    KTDocument          *_inspectedDocument;
}

@property(nonatomic, retain) KTDocument *inspectedDocument;

@end
