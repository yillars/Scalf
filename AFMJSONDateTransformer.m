//
//  AFMJSONDateTransformer.m
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import "AFMJSONDateTransformer.h"
#import "ISO8601DateFormatter.h"

NSString        *const MCJSONDateTimeTransformerName = @"MCJSONDateTimeTransformerName";
NSString        *const MCJSONDateOnlyTransformerName = @"MCJSONDateOnlyTransformerName";
static NSString *const kDateFormatDateTime           = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
static NSString *const kDateFormatDateOnly           = @"yyyy-MM-dd";

@interface AFMJSONDateTransformer ()

@property(nonatomic, strong) ISO8601DateFormatter *formatter;

@end

@implementation AFMJSONDateTransformer

+ (void)load {
    [NSValueTransformer setValueTransformer:[[self alloc] initWithDateStyle:MCJSONDateTransformerStyleDateTime] forName:MCJSONDateTimeTransformerName];
    [NSValueTransformer setValueTransformer:[[self alloc] initWithDateStyle:MCJSONDateTransformerStyleDateOnly] forName:MCJSONDateOnlyTransformerName];
}

+ (instancetype)valueTransformerWithDateStyle:(MCJSONDateTransformerStyle)style {
    return [[self alloc] initWithDateStyle:style];
}

- (instancetype)initWithDateStyle:(MCJSONDateTransformerStyle)style {
    self = [super init];
    if (self) {
        self.formatter             = [ISO8601DateFormatter new];
        self.formatter.includeTime = style == MCJSONDateTransformerStyleDateTime;
    }
    return self;
}

+ (Class)transformedValueClass {
    return [NSDate class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    id date_string = value[self.propertyKey];
    return date_string && date_string != [NSNull null] && [date_string isKindOfClass:NSString.class] ? [_formatter dateFromString:date_string] : date_string;
}

- (id)reverseTransformedValue:(id)value {
    return [self.formatter stringFromDate:value[self.propertyKey]];
}


@end
