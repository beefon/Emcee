import Foundation
import Models

class ResolvableResourceLocationImpl: ResolvableResourceLocation {
    let resourceLocation: ResourceLocation
    let resolver: ResourceLocationResolver
    
    init(resourceLocation: ResourceLocation, resolver: ResourceLocationResolver) {
        self.resourceLocation = resourceLocation
        self.resolver = resolver
    }

    init(withRepresentable representable: RepresentableByResourceLocation, resolver: ResourceLocationResolver) {
        self.resourceLocation = representable.resourceLocation
        self.resolver = resolver
    }
    
    func resolve() throws -> ResolvingResult {
        return try resolver.resolvePath(resourceLocation: resourceLocation)
    }
}
