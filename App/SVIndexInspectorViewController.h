//
//  SVIndexInspectorViewController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/31/10.
//  Copyright 2011 Karelia Software. All rights reserved.
//

//  Provides the standard Sandvox UI for selecting a collection to index. Further information can be found at
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import "SVInspectorViewController.h"


@class KTLinkSourceView;

@interface SVIndexInspectorViewController : SVInspectorViewController 
{
	IBOutlet KTLinkSourceView	*collectionLinkSourceView;
  @private
    id  _reserved6;
    id  _reserved7;
    id  _reserved8;
}

@end
