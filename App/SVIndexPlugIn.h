//
//  SVIndexPlugIn.h
//  Sandvox
//
//  Created by Mike on 10/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  +makeInspectorViewController will return a SVIndexInspectorViewController if no better class is provided by the plug-in. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html




#import "SVPlugIn.h"


@interface SVIndexPlugIn : SVPlugIn
{
  @private
    id                  _reserved3;
    id                  _reserved4;
    NSUInteger          _maxItems;
    BOOL                _enableMaxItems;
}

- (void)makeOriginalSize;   // indexes use this to set their width to nil

@property(nonatomic, retain, readonly) id <SVPage> indexedCollection;
@property(nonatomic) BOOL enableMaxItems;
@property(nonatomic) NSUInteger maxItems;

@property(nonatomic, readonly) NSArray *indexedPages;


#pragma mark HTML
// Called when there's no pages to go in the index. Default implementation simply writes out a bit of explanatory text, but you can override to provide a richer placeholder instead.
- (void)writePlaceholderHTML:(id <SVPlugInContext>)context;


@end
