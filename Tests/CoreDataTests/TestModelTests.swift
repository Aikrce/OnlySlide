import XCTest
import CoreData
@testable import CoreDataModule

final class TestModelTests: XCTestCase {
    
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        container = CoreDataTestHelper.createInMemoryContainer(modelName: "TestModel")
        context = container.viewContext
    }
    
    override func tearDownWithError() throws {
        try CoreDataTestHelper.cleanUpDatabase(context: context)
        container = nil
        context = nil
        try super.tearDownWithError()
    }
    
    func testCreateAndFetchTestEntity() throws {
        // 创建一个TestEntity实例
        let entity = NSEntityDescription.insertNewObject(forEntityName: "TestEntity", into: context) as! NSManagedObject
        
        let id = UUID()
        let name = "Test Name"
        let timestamp = Date()
        
        entity.setValue(id, forKey: "id")
        entity.setValue(name, forKey: "name")
        entity.setValue(timestamp, forKey: "timestamp")
        
        try context.save()
        
        // 验证保存成功
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "TestEntity")
        let fetchedResults = try context.fetch(fetchRequest)
        
        XCTAssertEqual(fetchedResults.count, 1, "应该正好找到一个实体")
        
        let fetchedEntity = fetchedResults.first!
        XCTAssertEqual(fetchedEntity.value(forKey: "id") as? UUID, id)
        XCTAssertEqual(fetchedEntity.value(forKey: "name") as? String, name)
        XCTAssertEqual(fetchedEntity.value(forKey: "timestamp") as? Date, timestamp)
    }
} 