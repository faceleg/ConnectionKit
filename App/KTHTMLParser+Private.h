//
//  KTHTMLParser+Private.h
//  Marvel
//
//  Created by Mike on 19/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLParser.h"


@interface KTHTMLParser (Private)

- (KTHTMLParserMasterCache *)cache;

- (KTHTMLParser *)newChildParserWithTemplate:(NSString *)templateHTML component:(id <KTWebViewComponent>)component;

- (NSString *)resourceFilePathRelativeToCurrentPage:(NSString *)resourceFile;
- (void)didEncounterResourceFile:(NSString *)resourcePath;

@end
