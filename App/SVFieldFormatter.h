//
//  SVFieldFormatter.h
//  Sandvox
//
//  Created by Mike on 25/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//	Limits input to a single line. Trims whitespace from string when ending editing. Suitable for subclassing. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html




#import <Cocoa/Cocoa.h>


@interface SVFieldFormatter : NSFormatter
{
  @private
    NSFormatter *_formatter;
}

@end
