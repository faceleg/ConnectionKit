//
//  SVWebLocation.h
//  Sandvox
//
//  Created by Mike on 04/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Represents a web location (e.g. a .webloc file). This is a URL and, optionally, a title. Further information can be found at
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>


@protocol SVWebLocation <NSObject>

#pragma mark Accessors
- (NSURL *)URL;
- (NSString *)title;

@end


#pragma mark -


@interface NSPasteboard (SVWebLocation)
- (NSArray *)readWebLocations;
@end


NSArray *SVWebLocationGetReadablePasteboardTypes(NSPasteboard *pasteboard);


#pragma mark -


@interface NSWorkspace (SVWebLocation)
- (id <SVWebLocation>)fetchBrowserWebLocation;
- (id <SVWebLocation>)fetchFeedWebLocation;
@end
