//
//  SVFieldFormatter.m
//  Sandvox
//
//  Created by Mike on 25/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//


#import "SVFieldFormatter.h"

#import "KSTrimFirstLineFormatter.h"


@implementation SVFieldFormatter

- (id)init;
{
    [super init];
    _formatter = [[KSTrimFirstLineFormatter alloc] init];
    return self;
}

- (void)dealloc;
{
    [_formatter release];
    
    [super dealloc];
}

- (NSString *)stringForObjectValue:(id)anObject
{
    return [_formatter stringForObjectValue:anObject];
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes
{
    return [_formatter attributedStringForObjectValue:anObject withDefaultAttributes:attributes];
}

- (NSString *)editingStringForObjectValue:(id)anObject
{
    return [_formatter editingStringForObjectValue:anObject];
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
    return [_formatter getObjectValue:anObject forString:string errorDescription:error];
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error
{
    return [_formatter isPartialStringValid:partialStringPtr proposedSelectedRange:proposedSelRangePtr originalString:origString originalSelectedRange:origSelRange errorDescription:error];
}

@end
