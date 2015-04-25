//
//  AFMJSONDateTransformer.h
//  RealmJSONDemo
//
//  Created by Matthew Cheok on 27/7/14.
//  Updated by Ali Kıran on 26/03/2015
//  Copyright (c) 2014 Matthew Cheok. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const MCJSONDateTimeTransformerName;
extern NSString *const MCJSONDateOnlyTransformerName;

typedef NS_ENUM(NSInteger, MCJSONDateTransformerStyle) {
    MCJSONDateTransformerStyleDateTime = 0,
    MCJSONDateTransformerStyleDateOnly
};

@interface AFMJSONDateTransformer : NSValueTransformer
@property(nonatomic, strong) Class propertyClass;
@property(nonatomic, copy) NSString *propertyKey;

+ (instancetype)valueTransformerWithDateStyle:(MCJSONDateTransformerStyle)style;

- (instancetype)initWithDateStyle:(MCJSONDateTransformerStyle)style;

@end
