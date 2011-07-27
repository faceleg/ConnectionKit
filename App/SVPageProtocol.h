//
//  SVPageProtocol.h
//  Sandvox
//
//  Created by Mike on 02/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>
#import "SVPlugIn.h"

@protocol SVPlugInContext;


enum {
    SVPageWritingSkipThumbnail = 1 << 0,
};
typedef NSUInteger SVPageWritingOptions;


@protocol SVPage <NSObject>;

#pragma mark Content

- (BOOL)writeContent:(id <SVPlugInContext>)context
			  plugIn:(SVPlugIn *)plugIn
			 options:(SVPageWritingOptions)options;

// For the image representation of a page, see SVPlugInContext


#pragma mark Properties

- (NSString *)title;
- (BOOL)showsTitle;

- (NSString *)language;             // KVO-compliant

@property(nonatomic, copy, readonly) NSString *fileNameExtension AVAILABLE_SANDVOX_VERSION_2_2_AND_LATER;

// Want to know the URL of a page? Ask SVPlugInContext


#pragma mark Dates
- (NSString *)timestampDescription; // nil if page does't have/want timestamp
@property(nonatomic, copy, readonly) NSDate *creationDate;
@property(nonatomic, copy, readonly) NSDate *modificationDate;
- (NSString *)timestampDescriptionWithDate:(NSDate *)date;


#pragma mark Hierarchy

@property(nonatomic, readonly) BOOL isCollection;
- (id <SVPage>)parentPage;
- (id <SVPage>)rootPage;

- (NSArray *)archivePages;


#pragma mark Navigation
- (BOOL)shouldIncludeInIndexes;
- (BOOL)shouldIncludeInSiteMaps;
@property(nonatomic, readonly) BOOL hasFeed;    // KVO-compliant


@end