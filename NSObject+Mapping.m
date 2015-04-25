//
// Created by Ali Kiran on 11/26/14.
// Copyright (c) 2014 Ali Kiran. All rights reserved.
//

#import <RegexKitLite/RegexKitLite.h>
#import "NSObject+Mapping.h"


@implementation NSObject (Mapping)

+ (Class)mc_normalizedClass {
    NSString *className = NSStringFromClass(self);
//    className = [className stringByReplacingOccurrencesOfString:@"RLMAccessor_" withString:@""];
//    className = [className stringByReplacingOccurrencesOfString:@"RLMStandalone_" withString:@""];
    className = [className stringByReplacingOccurrencesOfRegex:@"(RLMAccessor|RLAttribute|RLMStandalone)(_v[0-9]+)?_{0,1}" withString:@""];
    NSCAssert(className, @"");
    NSCAssert(![className containsString:@"RLMAccessor"], @"");
    NSCAssert(![className containsString:@"RLAttribute"], @"");
    NSCAssert(![className containsString:@"RLMStandalone"], @"");
    return NSClassFromString(className);
}

@end
