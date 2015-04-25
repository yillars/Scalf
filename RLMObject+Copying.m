//
//  RLMObject+Copying.m
//  Saleswhale
//
//  Created by Matthew Cheok on 26/8/14.
//  Copyright (c) 2014 Getting Real. All rights reserved.
//  Updated by Ali Kıran on 26/03/2015
//

#import "RLMObject+Copying.h"
#import "RLMObject+JSON.h"
#import "NSObject+Mapping.h"

@implementation RLMObject (Copying)

- (instancetype)shallowCopy {
    Class class  = [self.class mc_normalizedClass];
    id    object = [[class alloc] init];
    [object mergePropertiesFromObject:self];

    return object;
}

- (void)mergePropertiesFromObject:(id)object {
    for (RLMProperty *property in self.objectSchema.properties) {
        // assume array
        if (property.type == RLMPropertyTypeArray) {
            RLMArray *thisArray = [self valueForKeyPath:property.name];
            RLMArray *thatArray = [object valueForKeyPath:property.name];
            [thisArray addObjects:thatArray];
        } else {
            id value = [object valueForKeyPath:property.name];
            if (value)
                [self setValue:value forKeyPath:property.name];
        }
    }
}
//
//#pragma mark - Private
//
//+ (Class)mc_normalizedClass {
//    NSString *className = NSStringFromClass(self);
//    className = [className stringByReplacingOccurrencesOfString:@"RLMAccessor_" withString:@""];
//    className = [className stringByReplacingOccurrencesOfString:@"RLMStandalone_" withString:@""];
//    return NSClassFromString(className);
//}

@end
