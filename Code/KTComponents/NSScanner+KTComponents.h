//
//  NSScanner+KTComponents.h
//  KTComponents
//
//  Created by Dan Wood on 4/13/07.
//  Copyright (c) 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSScanner ( KTComponents )

-(BOOL) skipUpToCharactersFromSet:(NSCharacterSet*)set;

@end
