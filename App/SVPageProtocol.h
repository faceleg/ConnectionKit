//
//  SVPageProtocol.h
//  Sandvox
//
//  Created by Mike on 02/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPageletPlugIn.h"


@class SVLink, SVMedia;
@protocol SVMedia;


@protocol SVPage <NSObject>

- (NSString *)identifier;


#pragma mark Content
- (NSString *)title;
- (void)writeSummary:(id <SVPlugInContext>)context;


- (NSString *)language;

// Most SVPage methods aren't KVO-compliant. Instead, observe all of -automaticRearrangementKeyPaths.
@property(nonatomic, readonly) BOOL isCollection;   // or is it enough to test if childPages is non-nil?
- (NSArray *)childPages; 
- (id <SVPage>)rootPage;
- (id <NSFastEnumeration>)automaticRearrangementKeyPaths;

- (NSArray *)archivePages;


#pragma mark Navigation

- (SVLink *)link;
@property(nonatomic, readonly) NSURL *feedURL;  // KVO-compliant

- (BOOL)shouldIncludeInIndexes;
- (BOOL)shouldIncludeInSiteMaps;


@end


@interface SVPlugIn (SVPage)
- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
@end


// Posted when the page is to be deleted. Notification object is the page itself.
extern NSString *SVPageWillBeDeletedNotification;