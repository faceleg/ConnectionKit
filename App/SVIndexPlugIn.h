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

#pragma mark HTML

// THIS IS THE REAL MEAT OF AN INDEX PLUG-IN
// Returns an array of SVPage objects
// 
// OK, maybe I should ease off the capslock. As a general rule, your plug-in should loop through
// each page in this array, and generate HTML from them. e.g. write out the title, mod date,
// or summary. Perhaps even ask the context to generate a thumbnail
//
// By using this method, the system can calculate for you which pages to show. i.e. it'll filter
// out any the user has requested ([SVPage shouldIncludeInIndexes]). And cut off the array at
// -maxItems if appropriate
//
- (NSArray *)indexedPages;

// Called when there's no pages to go in the index. Default implementation simply writes out a bit of explanatory text, but you can override to provide a richer placeholder instead
- (void)writePlaceholderHTML:(id <SVPlugInContext>)context;


#pragma mark Properties
/*  The properties most indexes display in their inspector */
@property(nonatomic, retain, readonly) id <SVPage> indexedCollection;
@property(nonatomic) BOOL enableMaxItems;
@property(nonatomic) NSUInteger maxItems;


#pragma mark Metrics
// Plug-ins normally default to 200px wide. Indexes instead go for nil (auto) width
- (void)makeOriginalSize;


@end
