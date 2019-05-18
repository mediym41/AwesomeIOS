
import CoreData


extension NSFetchRequest {

    convenience init(entity: NSEntityDescription, predicate: NSPredicate? = nil, batchSize: Int = 0) {
        self.init()
        self.entity = entity
        self.predicate = predicate
        self.fetchBatchSize = batchSize
    }

}


