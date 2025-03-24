import Foundation
import CoreData
import os.log

public class TemplateRepository: ITemplateRepository {
    private let context: NSManagedObjectContext
    private let logger = Logger(label: "TemplateRepository")
    
    public init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }
    
    public func create(_ template: TemplateModel) async throws {
        do {
            let entity = Template(context: context)
            entity.id = template.id
            entity.name = template.name
            entity.content = template.content
            entity.category = template.category
            entity.metadata = template.metadata
            entity.createdAt = template.createdAt
            entity.updatedAt = template.updatedAt
            
            try context.save()
            logger.info("Created template with ID: \(template.id)")
        } catch {
            logger.error("Failed to create template: \(error)")
            throw CoreDataError.saveFailed(error.localizedDescription)
        }
    }
    
    public func get(byId id: UUID) async throws -> TemplateModel {
        let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            guard let template = try context.fetch(fetchRequest).first else {
                logger.warning("Template not found with ID: \(id)")
                throw CoreDataError.notFound("Template with ID \(id) not found")
            }
            return template.toDomain()
        } catch let error as CoreDataError {
            throw error
        } catch {
            logger.error("Failed to fetch template: \(error)")
            throw CoreDataError.fetchFailed(error.localizedDescription)
        }
    }
    
    public func update(_ template: TemplateModel) async throws {
        do {
            let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)
            
            guard let existingTemplate = try context.fetch(fetchRequest).first else {
                logger.warning("Template not found for update with ID: \(template.id)")
                throw CoreDataError.notFound("Template with ID \(template.id) not found")
            }
            
            existingTemplate.name = template.name
            existingTemplate.content = template.content
            existingTemplate.category = template.category
            existingTemplate.metadata = template.metadata
            existingTemplate.updatedAt = template.updatedAt
            
            try context.save()
            logger.info("Updated template with ID: \(template.id)")
        } catch let error as CoreDataError {
            throw error
        } catch {
            logger.error("Failed to update template: \(error)")
            throw CoreDataError.updateFailed(error.localizedDescription)
        }
    }
    
    public func delete(byId id: UUID) async throws {
        do {
            let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            guard let template = try context.fetch(fetchRequest).first else {
                logger.warning("Template not found for deletion with ID: \(id)")
                throw CoreDataError.notFound("Template with ID \(id) not found")
            }
            
            context.delete(template)
            try context.save()
            logger.info("Deleted template with ID: \(id)")
        } catch let error as CoreDataError {
            throw error
        } catch {
            logger.error("Failed to delete template: \(error)")
            throw CoreDataError.deleteFailed(error.localizedDescription)
        }
    }
    
    public func getAll() async throws -> [TemplateModel] {
        let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
        
        do {
            let templates = try context.fetch(fetchRequest)
            return templates.map { $0.toDomain() }
        } catch {
            logger.error("Failed to fetch all templates: \(error)")
            throw CoreDataError.fetchFailed(error.localizedDescription)
        }
    }
    
    public func search(query: String) async throws -> [TemplateModel] {
        let fetchRequest: NSFetchRequest<Template> = Template.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR content CONTAINS[cd] %@ OR category CONTAINS[cd] %@",
            query, query, query
        )
        
        do {
            let templates = try context.fetch(fetchRequest)
            return templates.map { $0.toDomain() }
        } catch {
            logger.error("Failed to search templates: \(error)")
            throw CoreDataError.fetchFailed(error.localizedDescription)
        }
    }
} 