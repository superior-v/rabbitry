import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/rabbit.dart';
import '../models/litter.dart';
import '../models/breed.dart';
import '../models/rabbit_document.dart';
import '../models/transaction.dart' as finance_model;
import 'dart:convert';
import 'settings_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rabbitry.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Rabbits table
    await db.execute('''
      CREATE TABLE rabbits(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        breed TEXT NOT NULL,
        location TEXT,
        cage TEXT,
        details TEXT,
        dateOfBirth TEXT,
        color TEXT,
        weight REAL,
        registrationNumber TEXT,
        sireId TEXT,
        damId TEXT,
        genetics TEXT,
        origin TEXT,
        photos TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastBreedDate TEXT,
        lastBreedBuckId TEXT,
        palpationDate TEXT,
        palpationResult INTEGER,
        dueDate TEXT,
        kindleDate TEXT,
        currentLitterSize INTEGER,
        weanDate TEXT,
        maturityDate TEXT,
        quarantineStartDate TEXT,
        quarantineEndDate TEXT,
        quarantineReason TEXT,
        archiveReason TEXT,
        archiveDate TEXT,
        archiveNotes TEXT,
        salePrice REAL,
        buyerInfo TEXT,
        butcherYield REAL,
        butcherCost REAL,
        deathCause TEXT,
        cullReason TEXT,
        customPalpationDay INTEGER,
        customNestBoxDay INTEGER,
        customGestationDay INTEGER,
        customWeanWeek INTEGER
      )
    ''');

    // Litters table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS litters (
        id TEXT PRIMARY KEY,
        doeId TEXT NOT NULL,
        doeName TEXT NOT NULL,
        buckId TEXT,
        buckName TEXT,
        breedDate TEXT NOT NULL,
        dueDate TEXT,
        kindleDate TEXT,
        totalBorn INTEGER DEFAULT 0,
        aliveBorn INTEGER DEFAULT 0,
        deadBorn INTEGER DEFAULT 0,
        currentAlive INTEGER DEFAULT 0,
        weanDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        dob TEXT,
        location TEXT,
        cage TEXT,
        breed TEXT,
        status TEXT,
        sire TEXT,
        dam TEXT,
        kits TEXT
      )
    ''');

    // Tasks table
    await db.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        rabbitId TEXT,
        litterId TEXT,
        title TEXT NOT NULL,
        description TEXT,
        taskType TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        completedAt TEXT,
        createdAt TEXT NOT NULL,
        ignored INTEGER DEFAULT 0,
        cost REAL
      )
    ''');

    // Schedules table (for recurring tasks)
    await db.execute('''
      CREATE TABLE schedules(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT,
        frequencyValue INTEGER NOT NULL,
        frequencyUnit TEXT NOT NULL,
        location TEXT,
        lastGenerated TEXT,
        active INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Health records table
    await db.execute('''
      CREATE TABLE health_records(
        id TEXT PRIMARY KEY,
        rabbitId TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        treatment TEXT,
        cost REAL,
        notes TEXT,
        active INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Weight records table
    await db.execute('''
      CREATE TABLE weight_records(
        id TEXT PRIMARY KEY,
        rabbitId TEXT NOT NULL,
        weight REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // Barns/Locations table
    await db.execute('''
      CREATE TABLE barns(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        rows TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        linkType TEXT NOT NULL,
        rabbitId TEXT,
        litterId TEXT,
        kitId TEXT,
        batchId TEXT,
        isBatchTransaction INTEGER DEFAULT 0,
        kitColor TEXT,
        kitSex TEXT,
        buyerInfo TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
  CREATE TABLE breeds(
    id TEXT PRIMARY KEY,
    name TEXT,
    genetics TEXT
  )
''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_directory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Documents table for rabbit file attachments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents(
        id TEXT PRIMARY KEY,
        rabbitId TEXT NOT NULL,
        name TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileType TEXT NOT NULL DEFAULT 'file',
        fileSize INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    print('✅ Database created successfully with all tables');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions(
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          description TEXT,
          notes TEXT,
          linkType TEXT NOT NULL,
          rabbitId TEXT,
          litterId TEXT,
          kitId TEXT,
          batchId TEXT,
          isBatchTransaction INTEGER DEFAULT 0,
          kitColor TEXT,
          kitSex TEXT,
          buyerInfo TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
      print('✅ Added transactions table');
    }

    if (oldVersion < 3) {
      // Add archive-related columns
      try {
        await db.execute('ALTER TABLE rabbits ADD COLUMN butcherYield REAL');
        print('✅ Added butcherYield column');
      } catch (e) {
        print('⚠️ butcherYield column may already exist');
      }

      try {
        await db.execute('ALTER TABLE rabbits ADD COLUMN butcherCost REAL');
        print('✅ Added butcherCost column');
      } catch (e) {
        print('⚠️ butcherCost column may already exist');
      }

      try {
        await db.execute('ALTER TABLE rabbits ADD COLUMN deathCause TEXT');
        print('✅ Added deathCause column');
      } catch (e) {
        print('⚠️ deathCause column may already exist');
      }

      try {
        await db.execute('ALTER TABLE rabbits ADD COLUMN cullReason TEXT');
        print('✅ Added cullReason column');
      } catch (e) {
        print('⚠️ cullReason column may already exist');
      }
    }

    if (oldVersion < 4) {
      // Add litter-related columns
      try {
        await db.execute('ALTER TABLE litters ADD COLUMN dob TEXT');
        await db.execute('ALTER TABLE litters ADD COLUMN location TEXT');
        await db.execute('ALTER TABLE litters ADD COLUMN cage TEXT');
        await db.execute('ALTER TABLE litters ADD COLUMN breed TEXT');
        await db.execute('ALTER TABLE litters ADD COLUMN sire TEXT');
        await db.execute('ALTER TABLE litters ADD COLUMN dam TEXT');
        await db.execute('ALTER TABLE litters ADD COLUMN kits TEXT');
        print('✅ Added litter management columns');
      } catch (e) {
        print('⚠️ Litter columns may already exist: $e');
      }
    }

    if (oldVersion < 5) {
      // Add ignored column to tasks for disable functionality
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN ignored INTEGER DEFAULT 0');
        print('✅ Added ignored column to tasks');
      } catch (e) {
        print('⚠️ ignored column may already exist: $e');
      }

      // Add cost column to tasks for cost logging
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN cost REAL');
        print('✅ Added cost column to tasks');
      } catch (e) {
        print('⚠️ cost column may already exist: $e');
      }
    }

    if (oldVersion < 6) {
      // Add schedules table for recurring tasks
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS schedules(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT,
            frequencyValue INTEGER NOT NULL,
            frequencyUnit TEXT NOT NULL,
            location TEXT,
            lastGenerated TEXT,
            active INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');
        print('✅ Added schedules table');
      } catch (e) {
        print('⚠️ schedules table may already exist: $e');
      }
    }

    if (oldVersion < 7) {
      // Add scheduled_tasks table for synchronized tasks across screens
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS scheduled_tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            frequency TEXT NOT NULL,
            linkType TEXT NOT NULL,
            linkedEntities TEXT,
            dueDate TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            completedAt TEXT
          )
        ''');
        print('✅ Added scheduled_tasks table');
      } catch (e) {
        print('⚠️ scheduled_tasks table may already exist: $e');
      }
    }

    if (oldVersion < 8) {
      // Add per-rabbit custom pipeline settings columns
      try {
        await db.execute('ALTER TABLE rabbits ADD COLUMN customPalpationDay INTEGER');
        await db.execute('ALTER TABLE rabbits ADD COLUMN customNestBoxDay INTEGER');
        await db.execute('ALTER TABLE rabbits ADD COLUMN customGestationDay INTEGER');
        await db.execute('ALTER TABLE rabbits ADD COLUMN customWeanWeek INTEGER');
        print('✅ Added custom pipeline columns to rabbits');
      } catch (e) {
        print('⚠️ Custom pipeline columns may already exist: $e');
      }
    }

    if (oldVersion < 9) {
      // Add breeds table for breed library with genetics
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS breeds(
            id TEXT PRIMARY KEY,
            name TEXT,
            genetics TEXT
          )
        ''');
        print('✅ Added breeds table');
      } catch (e) {
        print('⚠️ breeds table may already exist: $e');
      }
    }

    if (oldVersion < 10) {
      // Add task_directory table for user-defined task templates
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS task_directory(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        print('✅ Added task_directory table');
      } catch (e) {
        print('⚠️ task_directory table may already exist: $e');
      }
    }

    if (oldVersion < 11) {
      // Add documents table for rabbit file attachments
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS documents(
            id TEXT PRIMARY KEY,
            rabbitId TEXT NOT NULL,
            name TEXT NOT NULL,
            filePath TEXT NOT NULL,
            fileType TEXT NOT NULL DEFAULT 'file',
            fileSize INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
        print('✅ Added documents table');
      } catch (e) {
        print('⚠️ documents table may already exist: $e');
      }
    }

    if (oldVersion < 12) {
      // Add completedAt column to scheduled_tasks for day-end cleanup
      try {
        await db.execute('ALTER TABLE scheduled_tasks ADD COLUMN completedAt TEXT');
        print('✅ Added completedAt column to scheduled_tasks');
      } catch (e) {
        print('⚠️ completedAt column may already exist in scheduled_tasks: $e');
      }
      // Add completedAt column to tasks (pipeline tasks) for day-end cleanup
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
        print('✅ Added completedAt column to tasks');
      } catch (e) {
        print('⚠️ completedAt column may already exist in tasks: $e');
      }
    }
  }

  // ==================== RABBIT CRUD ====================

  Future<void> insertRabbit(Rabbit rabbit) async {
    final db = await database;
    await db.insert('rabbits', rabbit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted rabbit: ${rabbit.name}');
  }

  Future<List<Rabbit>> getAllRabbits() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'status != ?',
      whereArgs: [
        'RabbitStatus.archived'
      ],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Rabbit.fromMap(maps[i]));
  }

  Future<List<Rabbit>> getArchivedRabbits() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'status = ?',
      whereArgs: [
        'RabbitStatus.archived'
      ],
      orderBy: 'archiveDate DESC',
    );
    return List.generate(maps.length, (i) => Rabbit.fromMap(maps[i]));
  }

  Future<Rabbit?> getRabbit(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
    if (maps.isEmpty) return null;
    return Rabbit.fromMap(maps.first);
  }

  Future<List<Rabbit>> getRabbitsByType(RabbitType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'type = ? AND status != ?',
      whereArgs: [
        type.toString(),
        'RabbitStatus.archived'
      ],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Rabbit.fromMap(maps[i]));
  }

  Future<List<Rabbit>> getRabbitsByStatus(RabbitStatus status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'status = ?',
      whereArgs: [
        status.toString()
      ],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Rabbit.fromMap(maps[i]));
  }

  Future<List<Rabbit>> getRabbitsByTypeAndStatus(RabbitType type, RabbitStatus status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'type = ? AND status = ?',
      whereArgs: [
        type.toString(),
        status.toString()
      ],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Rabbit.fromMap(maps[i]));
  }

  Future<List<Rabbit>> getAvailableBucks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rabbits',
      where: 'type = ? AND status != ?',
      whereArgs: [
        'RabbitType.buck',
        'RabbitStatus.archived'
      ],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Rabbit.fromMap(maps[i]));
  }

  Future<void> updateRabbit(Rabbit rabbit) async {
    final db = await database;
    rabbit.updatedAt = DateTime.now();
    await db.update('rabbits', rabbit.toMap(), where: 'id = ?', whereArgs: [
      rabbit.id
    ]);
    print('✅ Updated rabbit: ${rabbit.name}');
  }

  Future<void> deleteRabbit(String id) async {
    final db = await database;
    await db.delete('rabbits', where: 'id = ?', whereArgs: [
      id
    ]);
    print('🗑️ Deleted rabbit: $id');
  }

  // ==================== BREEDING OPERATIONS ====================

  Future<void> logBreeding(String doeId, String buckId, DateTime breedDate, int gestationDays, {int? customPalpationDays, int? customNestBoxDays}) async {
    final db = await database;
    final settings = SettingsService.instance;
    final palpDays = customPalpationDays ?? settings.palpationDays;
    final nestDays = customNestBoxDays ?? settings.nestBoxDays;
    final palpationDate = breedDate.add(Duration(days: palpDays));
    final nestBoxDate = breedDate.add(Duration(days: nestDays));
    final dueDate = breedDate.add(Duration(days: gestationDays));

    // Determine initial status based on pipeline settings
    RabbitStatus initialStatus;
    if (settings.palpationEnabled) {
      initialStatus = RabbitStatus.palpateDue;
    } else if (settings.nestBoxEnabled) {
      initialStatus = RabbitStatus.pregnant;
    } else {
      initialStatus = RabbitStatus.pregnant;
    }

    await db.update(
      'rabbits',
      {
        'status': initialStatus.toString(),
        'lastBreedDate': breedDate.toIso8601String(),
        'lastBreedBuckId': buckId,
        'palpationDate': settings.palpationEnabled ? palpationDate.toIso8601String() : null,
        'dueDate': dueDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        doeId
      ],
    );

    // Create tasks based on pipeline settings
    if (settings.palpationEnabled) {
      // Palpation is enabled - create palpation task
      await insertTask({
        'id': 'task_palp_${DateTime.now().millisecondsSinceEpoch}',
        'rabbitId': doeId,
        'title': 'Palpation Check',
        'description': 'Day $palpDays pregnancy check',
        'taskType': 'palpation',
        'dueDate': palpationDate.toIso8601String(),
        'completed': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } else if (settings.nestBoxEnabled) {
      // Skip palpation, go directly to nest box
      await insertTask({
        'id': 'task_nest_${DateTime.now().millisecondsSinceEpoch}',
        'rabbitId': doeId,
        'title': 'Add Nest Box',
        'description': 'Prepare for kindling',
        'taskType': 'nestbox',
        'dueDate': nestBoxDate.toIso8601String(),
        'completed': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } else {
      // Skip both palpation and nest box, go directly to kindle
      await insertTask({
        'id': 'task_kindle_${DateTime.now().millisecondsSinceEpoch}',
        'rabbitId': doeId,
        'title': 'Expected Kindle',
        'description': 'Due date for birth',
        'taskType': 'kindle',
        'dueDate': dueDate.toIso8601String(),
        'completed': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    print('✅ Logged breeding for doe $doeId with buck $buckId');
  }

  Future<void> confirmPregnancy(String doeId, bool isPregnant, int gestationDays) async {
    final db = await database;
    final settings = SettingsService.instance;
    final rabbit = await getRabbit(doeId);
    if (rabbit == null) return;

    if (isPregnant) {
      final nestBoxDate = rabbit.dueDate!.subtract(Duration(days: 3));

      await db.update(
        'rabbits',
        {
          'status': RabbitStatus.pregnant.toString(),
          'palpationResult': 1,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [
          doeId
        ],
      );

      // Create tasks based on pipeline settings
      if (settings.nestBoxEnabled) {
        await insertTask({
          'id': 'task_nest_${DateTime.now().millisecondsSinceEpoch}',
          'rabbitId': doeId,
          'title': 'Add Nest Box',
          'description': 'Prepare for kindling',
          'taskType': 'nestbox',
          'dueDate': nestBoxDate.toIso8601String(),
          'completed': 0,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      await insertTask({
        'id': 'task_kindle_${DateTime.now().millisecondsSinceEpoch + 1}',
        'rabbitId': doeId,
        'title': 'Expected Kindle',
        'description': 'Due date for birth',
        'taskType': 'kindle',
        'dueDate': rabbit.dueDate!.toIso8601String(),
        'completed': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update(
        'rabbits',
        {
          'status': RabbitStatus.open.toString(),
          'palpationResult': 0,
          'lastBreedDate': null,
          'lastBreedBuckId': null,
          'palpationDate': null,
          'dueDate': null,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [
          doeId
        ],
      );
    }

    print('✅ Confirmed pregnancy for $doeId: $isPregnant');
  }

  Future<void> logBirth(String doeId, int totalBorn, int aliveBorn, DateTime kindleDate, int weaningWeeks, {String? litterId, List<Map<String, dynamic>>? kits}) async {
    final db = await database;
    final rabbit = await getRabbit(doeId);
    if (rabbit == null) return;

    final weanDate = kindleDate.add(Duration(days: weaningWeeks * 7));

    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.nursing.toString(),
        'kindleDate': kindleDate.toIso8601String(),
        'currentLitterSize': aliveBorn,
        'weanDate': weanDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        doeId
      ],
    );

    // ✅ Use custom litter ID if provided, otherwise generate sequential one
    final finalLitterId = litterId ?? await _generateNextLitterId();

    // ✅ Get buck name if available
    String buckName = '';
    if (rabbit.lastBreedBuckId != null) {
      final buck = await getRabbit(rabbit.lastBreedBuckId!);
      buckName = buck?.name ?? '';
    }

    // ✅ Encode kits to JSON string
    String kitsJson = '[]';
    if (kits != null && kits.isNotEmpty) {
      kitsJson = jsonEncode(kits);
    }

    await insertLitter({
      'id': finalLitterId,
      'doeId': doeId,
      'doeName': rabbit.name,
      'buckId': rabbit.lastBreedBuckId ?? '',
      'buckName': buckName,
      'breedDate': rabbit.lastBreedDate?.toIso8601String() ?? kindleDate.toIso8601String(),
      'kindleDate': kindleDate.toIso8601String(),
      'dob': kindleDate.toIso8601String(),
      'totalBorn': totalBorn,
      'aliveBorn': aliveBorn,
      'deadBorn': totalBorn - aliveBorn,
      'currentAlive': aliveBorn,
      'weanDate': weanDate.toIso8601String(),
      'status': 'nursing',
      'location': rabbit.location ?? '',
      'cage': rabbit.cage ?? '',
      'breed': rabbit.breed,
      'sire': buckName.isNotEmpty ? buckName : (rabbit.lastBreedBuckId ?? ''),
      'dam': rabbit.name,
      'kits': kitsJson,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await insertTask({
      'id': 'task_wean_${DateTime.now().millisecondsSinceEpoch}',
      'rabbitId': doeId,
      'litterId': finalLitterId,
      'title': 'Wean Litter',
      'description': '$aliveBorn kits ready for weaning',
      'taskType': 'wean',
      'dueDate': weanDate.toIso8601String(),
      'completed': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    print('✅ Logged birth for $doeId: $aliveBorn alive out of $totalBorn (Litter ID: $finalLitterId)');
  }

  /// Generate next sequential litter ID (L-001, L-002, etc.)
  Future<String> _generateNextLitterId() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT id FROM litters 
      WHERE id LIKE 'L-%' 
      ORDER BY id DESC 
      LIMIT 1
    ''');

    int nextNumber = 1;
    if (result.isNotEmpty) {
      final lastId = result.first['id'] as String;
      // Extract number from L-XXX format
      final numberPart = lastId.replaceAll(RegExp(r'[^0-9]'), '');
      if (numberPart.isNotEmpty) {
        nextNumber = int.parse(numberPart) + 1;
      }
    }

    return 'L-${nextNumber.toString().padLeft(3, '0')}';
  }

  /// Get next suggested litter ID for UI
  Future<String> getNextLitterId() async {
    return await _generateNextLitterId();
  }

  Future<void> weanLitter(String doeId, int weanedCount, int restingDays) async {
    final db = await database;
    final restingEndDate = DateTime.now().add(Duration(days: restingDays));

    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.resting.toString(),
        'currentLitterSize': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        doeId
      ],
    );

    await insertTask({
      'id': 'task_rest_${DateTime.now().millisecondsSinceEpoch}',
      'rabbitId': doeId,
      'title': 'Ready for Breeding',
      'description': 'Resting period complete',
      'taskType': 'open_breeding',
      'dueDate': restingEndDate.toIso8601String(),
      'completed': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    print('✅ Weaned litter for $doeId: $weanedCount kits');
  }

  Future<void> markOpenForBreeding(String doeId) async {
    final db = await database;
    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.open.toString(),
        'lastBreedDate': null,
        'lastBreedBuckId': null,
        'palpationDate': null,
        'palpationResult': null,
        'dueDate': null,
        'kindleDate': null,
        'currentLitterSize': null,
        'weanDate': null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        doeId
      ],
    );
    print('✅ Marked $doeId as open for breeding');
  }

  // Cancel pregnancy and remove all associated breeding tasks
  Future<void> cancelPregnancy(String doeId) async {
    final db = await database;

    // Reset doe status to open
    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.open.toString(),
        'lastBreedDate': null,
        'lastBreedBuckId': null,
        'palpationDate': null,
        'palpationResult': null,
        'dueDate': null,
        'kindleDate': null,
        'currentLitterSize': null,
        'weanDate': null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        doeId
      ],
    );

    // Delete all associated tasks for this rabbit (breeding-related)
    await db.delete(
      'tasks',
      where: 'rabbitId = ? AND taskType IN (?, ?, ?, ?, ?)',
      whereArgs: [
        doeId,
        'palpation',
        'nestbox',
        'kindle',
        'wean',
        'open_breeding'
      ],
    );

    print('✅ Cancelled pregnancy for $doeId and removed all associated tasks');
  }

  // ==================== QUARANTINE ====================

  Future<void> addToQuarantine(
    String rabbitId,
    String reason,
    int days,
    double? expense,
  ) async {
    final db = await database;
    final endDate = DateTime.now().add(Duration(days: days));

    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.quarantine.toString(),
        'quarantineStartDate': DateTime.now().toIso8601String(),
        'quarantineEndDate': endDate.toIso8601String(),
        'quarantineReason': reason,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        rabbitId
      ],
    );

    if (expense != null && expense > 0) {
      await insertHealthRecord({
        'id': 'health_${DateTime.now().millisecondsSinceEpoch}',
        'rabbitId': rabbitId,
        'type': 'quarantine',
        'date': DateTime.now().toIso8601String(),
        'treatment': null,
        'cost': expense,
        'notes': reason,
        'active': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    await insertTask({
      'id': 'task_quar_${DateTime.now().millisecondsSinceEpoch}',
      'rabbitId': rabbitId,
      'title': 'End Quarantine',
      'description': 'Review and release from quarantine',
      'taskType': 'quarantine_end',
      'dueDate': endDate.toIso8601String(),
      'completed': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    print('✅ Added $rabbitId to quarantine for $days days');
  }

  Future<void> endQuarantine(String rabbitId, RabbitStatus newStatus, String? newCage) async {
    final db = await database;
    final updates = <String, dynamic>{
      'status': newStatus.toString(),
      'quarantineStartDate': null,
      'quarantineEndDate': null,
      'quarantineReason': null,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (newCage != null && newCage.isNotEmpty) {
      updates['cage'] = newCage;
    }

    await db.update('rabbits', updates, where: 'id = ?', whereArgs: [
      rabbitId
    ]);
    print('✅ Ended quarantine for $rabbitId');
  }

  // Cancel quarantine-related tasks for a rabbit
  Future<void> cancelQuarantineTasks(String rabbitId) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'completed': 1,
        'completedAt': DateTime.now().toIso8601String(),
      },
      where: 'rabbitId = ? AND taskType = ? AND completed = ?',
      whereArgs: [
        rabbitId,
        'quarantine_end',
        0
      ],
    );
    print('✅ Cancelled quarantine tasks for $rabbitId');
  }

  // ==================== ARCHIVE ====================

  Future<void> archiveRabbit(
    String rabbitId,
    ArchiveReason reason,
    String? notes,
    double? salePrice,
    String? buyerInfo,
    double? butcherYield,
    double? butcherCost,
    String? deathCause,
    String? cullReason,
  ) async {
    final db = await database;

    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.archived.toString(),
        'archiveReason': reason.toString(),
        'archiveDate': DateTime.now().toIso8601String(),
        'archiveNotes': notes,
        'salePrice': salePrice,
        'buyerInfo': buyerInfo,
        'butcherYield': butcherYield,
        'butcherCost': butcherCost,
        'deathCause': deathCause,
        'cullReason': cullReason,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        rabbitId
      ],
    );

    print('✅ Archived rabbit $rabbitId: $reason');
  }

  // ==================== GROWOUT ====================

  Future<void> promoteToBreeder(String rabbitId) async {
    final db = await database;
    await db.update(
      'rabbits',
      {
        'status': RabbitStatus.open.toString(),
        'maturityDate': null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        rabbitId
      ],
    );
    print('✅ Promoted $rabbitId to breeder');
  }

  /// Promotes a kit from a litter to a full rabbit (active breeder)
  /// Creates a new rabbit entry and updates the kit status
  Future<Rabbit?> promoteKitToBreeder(
    Litter litter,
    Kit kit, {
    String? customName,
    String? customId,
    RabbitType? type,
    String? breed,
    String? location,
    String? cage,
    DateTime? dateOfBirth,
    String? color,
    double? weight,
    String? notes,
  }) async {
    // Generate a new rabbit ID
    final rabbitType = type ?? (kit.sex == 'M' ? RabbitType.buck : RabbitType.doe);
    final typePrefix = rabbitType == RabbitType.buck ? 'B' : 'D';
    final newRabbitId = customId ?? '$typePrefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final rabbitName = customName ?? 'Kit ${kit.id}';

    // Create the new rabbit
    final newRabbit = Rabbit(
      id: newRabbitId,
      name: rabbitName,
      type: rabbitType,
      status: RabbitStatus.open, // Active breeder - ready for breeding
      breed: breed ?? litter.breed,
      location: location ?? litter.location,
      cage: cage ?? litter.cage,
      dateOfBirth: dateOfBirth ?? litter.dob,
      color: color ?? kit.color,
      weight: weight ?? kit.weight,
      sireId: litter.buckId,
      damId: litter.doeId,
      origin: 'Homebred',
      notes: notes ?? 'Promoted from litter ${litter.id}',
    );

    // Insert the new rabbit
    await insertRabbit(newRabbit);

    // Sync cage into barn row
    final cageVal = cage ?? litter.cage;
    final locVal = location ?? litter.location;
    if (locVal.isNotEmpty && cageVal.isNotEmpty) {
      await syncCageToBarn(locVal, cageVal);
    }

    // Update the kit status to 'Promoted'
    final updatedKits = litter.kits.map((k) {
      if (k.id == kit.id) {
        return k.copyWith(status: 'Promoted');
      }
      return k;
    }).toList();

    final updatedLitter = litter.copyWith(kits: updatedKits);
    await updateLitter(updatedLitter);

    print('✅ Promoted kit ${kit.id} from litter ${litter.id} to breeder $newRabbitId');
    return newRabbit;
  }

  // ==================== MOVE CAGE ====================

  /// Ensures a cage exists in the barn row. If the row has the given location
  /// name and the cage isn't already in its cages list, it gets added.
  Future<void> syncCageToBarn(String location, String cage) async {
    if (location.isEmpty || cage.isEmpty) return;
    final barnsData = await getAllBarns();
    for (var barnMap in barnsData) {
      List<dynamic> rows = [];
      final rowsRaw = barnMap['rows'];
      if (rowsRaw is String && rowsRaw.isNotEmpty) {
        try {
          rows = jsonDecode(rowsRaw) as List<dynamic>;
        } catch (_) {}
      }
      bool updated = false;
      for (var row in rows) {
        if (row is Map && row['name'] == location) {
          final cages = List<String>.from(row['cages'] ?? []);
          if (!cages.contains(cage)) {
            cages.add(cage);
            row['cages'] = cages;
            updated = true;
          }
        }
      }
      if (updated) {
        final db = await database;
        await db.update(
          'barns',
          {
            'rows': jsonEncode(rows)
          },
          where: 'id = ?',
          whereArgs: [
            barnMap['id']
          ],
        );
        print('✅ Synced cage "$cage" into barn "${barnMap['name']}" → row "$location"');
      }
    }
  }

  Future<void> moveCage(String rabbitId, String newLocation, String newCage) async {
    final db = await database;
    await db.update(
      'rabbits',
      {
        'location': newLocation,
        'cage': newCage,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        rabbitId
      ],
    );
    // Sync cage into barn row
    await syncCageToBarn(newLocation, newCage);
    print('✅ Moved $rabbitId to $newLocation - $newCage');
  }

  // Update litter location by doe ID (for moving litter after weaning)
  Future<void> updateLitterLocation(String doeId, String location, String cage) async {
    final db = await database;
    await db.update(
      'litters',
      {
        'location': location,
        'cage': cage,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'doeId = ? AND status = ?',
      whereArgs: [
        doeId,
        'nursing'
      ],
    );
    // Sync cage into barn row
    await syncCageToBarn(location, cage);
    print('✅ Updated litter location for $doeId to $location - $cage');
  }

  // ==================== LITTER CRUD ====================

  Future<void> insertLitter(Map<String, dynamic> litter) async {
    final db = await database;
    await db.insert('litters', litter, conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted litter: ${litter['id']}');
  }

  // ✅ NEW: Get all litters as Litter objects
  // Replace the getLitters() method at line 770 with this:

  Future<List<Litter>> getLitters() async {
    try {
      final db = await database;

      // Run migration first
      await _migrateLittersTable(db);

      final result = await db.query(
        'litters',
        orderBy: 'breedDate DESC',
      );

      if (result.isEmpty) {
        print('📦 No litters in database');
        return [];
      }

      print('📦 Found ${result.length} litters in database');

      final litters = <Litter>[];
      for (var map in result) {
        try {
          print('  🔄 Parsing litter ${map['id']}...');
          print('     - dob: ${map['dob']}');
          print('     - location: ${map['location']}');
          print('     - cage: ${map['cage']}');
          print('     - kits: ${map['kits']?.toString().substring(0, (map['kits']?.toString().length ?? 0).clamp(0, 50))}...');

          final litter = Litter.fromMap(map);
          litters.add(litter);
          print('  ✅ Parsed litter ${map['id']} with ${litter.kits.length} kits');
        } catch (e) {
          print('  ❌ Error parsing litter ${map['id']}: $e');
        }
      }

      return litters;
    } catch (e, stackTrace) {
      print('❌ Error getting litters: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllLitters() async {
    final db = await database;
    return await db.query('litters', orderBy: 'breedDate DESC');
  }

  Future<List<Map<String, dynamic>>> getLittersByDoe(String doeId) async {
    final db = await database;
    return await db.query(
      'litters',
      where: 'doeId = ?',
      whereArgs: [
        doeId
      ],
      orderBy: 'breedDate DESC',
    );
  }

  // ✅ NEW: Get single litter
  Future<Litter?> getLitter(String litterId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'litters',
      where: 'id = ?',
      whereArgs: [
        litterId
      ],
    );
    if (maps.isEmpty) return null;
    return Litter.fromMap(maps.first);
  }

  // ✅ NEW: Update litter

  Future<void> updateLitter(Litter litter) async {
    try {
      final db = await database;

      // Run migration first to ensure columns exist
      await _migrateLittersTable(db);

      final existingLitters = await db.query(
        'litters',
        where: 'id = ?',
        whereArgs: [
          litter.id
        ],
      );

      // Encode kits to JSON string
      String kitsJson = '[]';
      try {
        kitsJson = jsonEncode(litter.kits.map((k) => k.toMap()).toList());
      } catch (e) {
        print('❌ Error encoding kits: $e');
      }

      final litterData = {
        'id': litter.id,
        'doeId': litter.doeId,
        'doeName': litter.doeName,
        'buckId': litter.buckId ?? '',
        'buckName': litter.buckName ?? '',
        'breedDate': litter.breedDate.toIso8601String(),
        'dueDate': litter.dueDate?.toIso8601String(),
        'kindleDate': litter.kindleDate?.toIso8601String(),
        'totalBorn': litter.totalKits,
        'aliveBorn': litter.aliveKits,
        'deadBorn': litter.deadKits,
        'currentAlive': litter.aliveKits,
        'weanDate': litter.weanDate?.toIso8601String(),
        'notes': litter.notes,
        'updatedAt': DateTime.now().toIso8601String(),
        'dob': litter.dob.toIso8601String(),
        'location': litter.location,
        'cage': litter.cage,
        'breed': litter.breed,
        'status': litter.status,
        'sire': litter.sire,
        'dam': litter.dam,
        'kits': kitsJson,
      };

      if (existingLitters.isEmpty) {
        litterData['createdAt'] = DateTime.now().toIso8601String();
        await db.insert('litters', litterData);
        print('✅ Inserted litter: ${litter.id} with ${litter.kits.length} kits');
      } else {
        await db.update(
          'litters',
          litterData,
          where: 'id = ?',
          whereArgs: [
            litter.id
          ],
        );
        print('✅ Updated litter: ${litter.id} with ${litter.kits.length} kits');
      }
    } catch (e, stackTrace) {
      print('❌ Error updating litter: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> clearAllLitters() async {
    final db = await database;
    await db.delete('litters');
    print('🗑️ Cleared all litters from database');
  }

  // ✅ NEW: Update specific kit in litter
  Future<void> updateKit(String litterId, Kit kit) async {
    final db = await database;

    // Get current litter
    final litter = await getLitter(litterId);
    if (litter == null) return;

    // Update the kit in the kits list
    final updatedKits = litter.kits.map((k) {
      if (k.id == kit.id) {
        return kit;
      }
      return k;
    }).toList();

    // Save back to database
    final updatedLitter = litter.copyWith(kits: updatedKits);
    await updateLitter(updatedLitter);

    print('✅ Updated kit ${kit.id} in litter $litterId');
  }

  // ✅ NEW: Delete litter
  Future<void> deleteLitter(String litterId) async {
    final db = await database;
    await db.delete('litters', where: 'id = ?', whereArgs: [
      litterId
    ]);
    print('🗑️ Deleted litter: $litterId');
  }

  // ==================== TASK CRUD ====================

  Future<void> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('tasks', task, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await database;
    await _ensureTasksIgnoredColumn(db);
    return await db.query('tasks', where: 'ignored = 0 OR ignored IS NULL', orderBy: 'dueDate ASC');
  }

  /// Ensure the 'ignored' column exists on the tasks table (handles fresh installs pre-fix)
  Future<void> _ensureTasksIgnoredColumn(Database db) async {
    try {
      await db.execute('ALTER TABLE tasks ADD COLUMN ignored INTEGER DEFAULT 0');
    } catch (_) {
      // Column already exists — ignore
    }
    try {
      await db.execute('ALTER TABLE tasks ADD COLUMN cost REAL');
    } catch (_) {
      // Column already exists — ignore
    }
    try {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
    } catch (_) {
      // Column already exists — ignore
    }
  }

  /// Get pipeline tasks due today or overdue, normalized for home dashboard display
  /// Includes uncompleted tasks AND tasks completed today (so they stay visible)
  Future<List<Map<String, dynamic>>> getPipelineTasksDueToday({bool snowballEffect = true}) async {
    final db = await database;
    await _ensureTasksIgnoredColumn(db);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final List<Map<String, dynamic>> tasks;
    if (snowballEffect) {
      // Snowball ON: show overdue + today
      tasks = await db.query(
        'tasks',
        where: '(ignored = 0 OR ignored IS NULL) AND dueDate <= ? AND (completed = 0 OR (completed = 1 AND completedAt >= ?))',
        whereArgs: [
          todayEnd.toIso8601String(),
          todayStart.toIso8601String(),
        ],
        orderBy: 'dueDate ASC',
      );
    } else {
      // Snowball OFF: only show tasks due today (not overdue)
      tasks = await db.query(
        'tasks',
        where: '(ignored = 0 OR ignored IS NULL) AND dueDate >= ? AND dueDate <= ? AND (completed = 0 OR (completed = 1 AND completedAt >= ?))',
        whereArgs: [
          todayStart.toIso8601String(),
          todayEnd.toIso8601String(),
          todayStart.toIso8601String(),
        ],
        orderBy: 'dueDate ASC',
      );
    }

    return _normalizePipelineTasks(tasks);
  }

  /// Get all active pipeline tasks (for settings display)
  Future<List<Map<String, dynamic>>> getAllPipelineTasks() async {
    final db = await database;
    await _ensureTasksIgnoredColumn(db);
    final tasks = await db.query(
      'tasks',
      where: 'completed = 0 AND (ignored = 0 OR ignored IS NULL)',
      orderBy: 'dueDate ASC',
    );
    return _normalizePipelineTasks(tasks);
  }

  /// Get upcoming pipeline tasks (future), normalized for home dashboard display
  Future<List<Map<String, dynamic>>> getUpcomingPipelineTasks() async {
    final db = await database;
    await _ensureTasksIgnoredColumn(db);
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final tasks = await db.query(
      'tasks',
      where: '(ignored = 0 OR ignored IS NULL) AND dueDate > ? AND (completed = 0 OR (completed = 1 AND completedAt >= ?))',
      whereArgs: [
        todayEnd.toIso8601String(),
        todayStart,
      ],
      orderBy: 'dueDate ASC',
    );

    return _normalizePipelineTasks(tasks);
  }

  /// Normalize pipeline tasks to the same format as scheduled tasks for the home dashboard
  Future<List<Map<String, dynamic>>> _normalizePipelineTasks(List<Map<String, dynamic>> tasks) async {
    final List<Map<String, dynamic>> normalized = [];

    for (final task in tasks) {
      final taskType = task['taskType']?.toString() ?? '';
      final rabbitId = task['rabbitId']?.toString() ?? '';
      final litterId = task['litterId']?.toString() ?? '';

      // Get entity name for display
      String entityName = rabbitId;
      String entityCage = '';

      // For litter-linked tasks, prefer litter info (doe name, litter ID)
      if (litterId.isNotEmpty) {
        final litter = await getLitter(litterId);
        if (litter != null) {
          final doeName = litter.doeName.isNotEmpty ? litter.doeName : '';
          final kits = litter.aliveKits ?? 0;
          if (doeName.isNotEmpty) {
            entityName = '$doeName${kits > 0 ? ' ($kits kits)' : ''}';
          } else {
            entityName = 'Litter $litterId';
          }
          entityCage = litter.cage.isNotEmpty ? litter.cage : litter.location;
        }
      } else if (rabbitId.isNotEmpty) {
        final rabbit = await getRabbit(rabbitId);
        if (rabbit != null) {
          entityName = rabbit.name.isNotEmpty ? rabbit.name : rabbit.id;
          entityCage = rabbit.cage ?? '';
        }
      }

      // Map taskType to display name and category
      String displayName;
      String category;
      switch (taskType) {
        case 'palpation':
          displayName = 'Palpation Check';
          category = 'Reproduction';
          break;
        case 'nestbox':
          displayName = 'Add Nest Box';
          category = 'Reproduction';
          break;
        case 'kindle':
          displayName = 'Expected Kindle';
          category = 'Reproduction';
          break;
        case 'wean':
          displayName = 'Wean Litter';
          category = 'Reproduction';
          break;
        case 'open_breeding':
          displayName = 'Ready to Breed';
          category = 'Reproduction';
          break;
        case 'quarantine_end':
          displayName = 'Quarantine End';
          category = 'Health';
          break;
        default:
          displayName = task['title']?.toString() ?? 'Task';
          category = 'Operations';
      }

      normalized.add({
        'id': task['id'], // String ID from tasks table
        'isPipelineTask': true, // Flag to distinguish from scheduled tasks
        'task': displayName,
        'name': displayName,
        'category': category,
        'frequency': 'Once',
        'linkType': 'rabbit',
        'taskType': taskType,
        'rabbitId': rabbitId,
        'litterId': litterId,
        'linkedEntities': [
          {
            'id': rabbitId,
            'name': entityName,
            'cage': entityCage
          }
        ],
        'dueDate': task['dueDate'],
        'createdAt': task['createdAt'],
        'completedAt': task['completedAt'],
      });
    }

    return normalized;
  }

  Future<List<Map<String, dynamic>>> getUpcomingTasks({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'tasks',
      where: 'completed = 0 AND (ignored = 0 OR ignored IS NULL)',
      orderBy: 'dueDate ASC',
      limit: limit,
    );
  }

  /// Get pipeline tasks for a specific rabbit, normalized for display
  Future<List<Map<String, dynamic>>> getPipelineTasksForRabbit(String rabbitId) async {
    final db = await database;
    await _ensureTasksIgnoredColumn(db);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final tasks = await db.query(
      'tasks',
      where: '(ignored = 0 OR ignored IS NULL) AND rabbitId = ? AND (completed = 0 OR (completed = 1 AND completedAt >= ?))',
      whereArgs: [
        rabbitId,
        todayStart,
      ],
      orderBy: 'dueDate ASC',
    );
    return _normalizePipelineTasks(tasks);
  }

  Future<void> completeTask(String taskId) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'completed': 1,
        'completedAt': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [
        taskId
      ],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [
      id
    ]);
  }

  // Ignore/Disable a task (task is hidden but not deleted)
  Future<void> ignoreTask(String taskId) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'ignored': 1
      },
      where: 'id = ?',
      whereArgs: [
        taskId
      ],
    );
    print('✅ Task $taskId ignored/disabled');
  }

  // Complete task with optional cost logging
  Future<void> completeTaskWithCost(String taskId, double? cost, String? rabbitId, {String? taskTitle, String? taskCategory}) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'completed': 1,
        'completedAt': DateTime.now().toIso8601String(),
        'cost': cost,
      },
      where: 'id = ?',
      whereArgs: [
        taskId
      ],
    );

    // If cost is provided, log it as a transaction
    if (cost != null && cost > 0) {
      final txnCategory = _mapTaskCategoryToTransactionCategory(taskCategory);
      final transaction = finance_model.Transaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        type: finance_model.TransactionType.expense,
        category: txnCategory,
        amount: cost,
        date: DateTime.now(),
        description: taskTitle ?? 'Task cost',
        notes: 'Logged from completed task',
        linkType: rabbitId != null ? finance_model.LinkType.rabbit : finance_model.LinkType.general,
        rabbitId: rabbitId,
      );
      await insertTransaction(transaction);
      print('✅ Task completed with cost: \$$cost');
    }
  }

  // Complete scheduled task with optional cost logging
  Future<void> markScheduledTaskCompletedWithCost(int id, double? cost, {String? taskTitle, String? taskCategory, String? rabbitId}) async {
    final db = await database;
    await db.update(
      'scheduled_tasks',
      {
        'completedAt': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );

    // If cost is provided, log it as a transaction
    if (cost != null && cost > 0) {
      final txnCategory = _mapTaskCategoryToTransactionCategory(taskCategory);
      final transaction = finance_model.Transaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        type: finance_model.TransactionType.expense,
        category: txnCategory,
        amount: cost,
        date: DateTime.now(),
        description: taskTitle ?? 'Task cost',
        notes: 'Logged from completed task',
        linkType: rabbitId != null ? finance_model.LinkType.rabbit : finance_model.LinkType.general,
        rabbitId: rabbitId,
      );
      await insertTransaction(transaction);
      print('✅ Scheduled task completed with cost: \$$cost');
    }
  }

  // Map task category to transaction expense category
  finance_model.TransactionCategory _mapTaskCategoryToTransactionCategory(String? taskCategory) {
    switch (taskCategory?.toLowerCase()) {
      case 'health':
        return finance_model.TransactionCategory.medical;
      case 'maintenance':
        return finance_model.TransactionCategory.equipment;
      case 'butchering':
        return finance_model.TransactionCategory.supplies;
      default:
        return finance_model.TransactionCategory.otherExpense;
    }
  }

  // ==================== SCHEDULES (RECURRING TASKS) ====================

  Future<void> insertSchedule(Map<String, dynamic> schedule) async {
    final db = await database;

    // Validate and convert frequency string to value + unit
    String frequencyStr = schedule['frequency'] ?? 'Weekly';
    int frequencyValue = 1;
    String frequencyUnit = 'weeks';

    switch (frequencyStr.toLowerCase()) {
      case 'daily':
        frequencyValue = 1;
        frequencyUnit = 'days';
        break;
      case 'weekly':
        frequencyValue = 1;
        frequencyUnit = 'weeks';
        break;
      case 'monthly':
        frequencyValue = 1;
        frequencyUnit = 'months';
        break;
    }

    final scheduleData = {
      'id': schedule['id'],
      'title': schedule['title'],
      'category': schedule['category'],
      'frequencyValue': frequencyValue,
      'frequencyUnit': frequencyUnit,
      'location': schedule['location'],
      'lastGenerated': null,
      'active': schedule['active'] ?? 1,
      'createdAt': schedule['createdAt'] ?? DateTime.now().toIso8601String(),
    };

    await db.insert('schedules', scheduleData, conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted schedule: ${schedule['title']} (Every $frequencyValue $frequencyUnit)');

    // Generate the first task from this schedule
    await generateTaskFromSchedule(scheduleData);
  }

  Future<List<Map<String, dynamic>>> getAllSchedules() async {
    final db = await database;
    return await db.query('schedules', where: 'active = 1', orderBy: 'createdAt DESC');
  }

  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [
      id
    ]);
    print('✅ Deleted schedule: $id');
  }

  /// Generates a task from a recurring schedule
  Future<void> generateTaskFromSchedule(Map<String, dynamic> schedule) async {
    final db = await database;

    // Calculate next due date based on frequency
    DateTime nextDueDate = DateTime.now();
    final frequencyValue = schedule['frequencyValue'] as int;
    final frequencyUnit = schedule['frequencyUnit'] as String;

    switch (frequencyUnit) {
      case 'days':
        nextDueDate = nextDueDate.add(Duration(days: frequencyValue));
        break;
      case 'weeks':
        nextDueDate = nextDueDate.add(Duration(days: frequencyValue * 7));
        break;
      case 'months':
        nextDueDate = DateTime(nextDueDate.year, nextDueDate.month + frequencyValue, nextDueDate.day);
        break;
      case 'years':
        nextDueDate = DateTime(nextDueDate.year + frequencyValue, nextDueDate.month, nextDueDate.day);
        break;
    }

    // Create the task
    final taskId = 'task_schedule_${schedule['id']}_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('tasks', {
      'id': taskId,
      'title': schedule['title'],
      'description': 'Recurring: Every $frequencyValue $frequencyUnit',
      'taskType': schedule['category'] ?? 'custom',
      'dueDate': nextDueDate.toIso8601String(),
      'completed': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Update lastGenerated on the schedule
    await db.update(
      'schedules',
      {
        'lastGenerated': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [
        schedule['id']
      ],
    );

    print('✅ Generated task from schedule: ${schedule['title']} due on $nextDueDate');
  }

  /// Regenerates task when a recurring task is completed
  Future<void> completeRecurringTask(String taskId) async {
    final db = await database;

    // Complete the current task
    await completeTask(taskId);

    // Check if this task came from a schedule (id starts with 'task_schedule_')
    if (taskId.startsWith('task_schedule_')) {
      // Extract schedule ID from task ID (format: task_schedule_{scheduleId}_{timestamp})
      final parts = taskId.split('_');
      if (parts.length >= 3) {
        final scheduleId = parts[2];
        final schedules = await db.query('schedules', where: 'id = ?', whereArgs: [
          scheduleId
        ]);
        if (schedules.isNotEmpty) {
          await generateTaskFromSchedule(schedules.first);
        }
      }
    }
  }

  // ==================== HEALTH RECORDS ====================

  Future<void> insertHealthRecord(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert('health_records', record, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addHealthRecord(
    String rabbitId,
    String type,
    DateTime date,
    String treatment,
    double? cost,
    String? notes,
  ) async {
    final db = await database;
    await db.insert('health_records', {
      'id': 'health_${DateTime.now().millisecondsSinceEpoch}',
      'rabbitId': rabbitId,
      'type': type,
      'date': date.toIso8601String(),
      'treatment': treatment,
      'cost': cost,
      'notes': notes,
      'active': 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
    print('✅ Added health record for $rabbitId');
  }

  Future<List<Map<String, dynamic>>> getHealthRecordsByRabbit(String rabbitId) async {
    final db = await database;
    return await db.query(
      'health_records',
      where: 'rabbitId = ?',
      whereArgs: [
        rabbitId
      ],
      orderBy: 'date DESC',
    );
  }

  // ==================== WEIGHT RECORDS ====================

  Future<void> insertWeightRecord(String rabbitId, double weight, DateTime date, String? notes) async {
    final db = await database;
    await db.insert('weight_records', {
      'id': 'weight_${DateTime.now().millisecondsSinceEpoch}',
      'rabbitId': rabbitId,
      'weight': weight,
      'date': date.toIso8601String(),
      'notes': notes,
    });

    await db.update(
      'rabbits',
      {
        'weight': weight,
        'updatedAt': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [
        rabbitId
      ],
    );

    print('✅ Inserted weight record for $rabbitId: $weight');
  }

  Future<void> logWeight(String rabbitId, double weight, DateTime date, String? notes) async {
    await insertWeightRecord(rabbitId, weight, date, notes);
  }

  Future<List<Map<String, dynamic>>> getWeightHistory(String rabbitId) async {
    final db = await database;
    return await db.query(
      'weight_records',
      where: 'rabbitId = ?',
      whereArgs: [
        rabbitId
      ],
      orderBy: 'date DESC',
    );
  }

  // Delete a specific weight record
  Future<void> deleteWeightRecord(String weightRecordId) async {
    final db = await database;
    await db.delete('weight_records', where: 'id = ?', whereArgs: [
      weightRecordId
    ]);
    print('✅ Deleted weight record: $weightRecordId');
  }

  // ==================== BARNS/LOCATIONS ====================

  Future<void> insertBarn(Map<String, dynamic> barn) async {
    final db = await database;
    final barnData = Map<String, dynamic>.from(barn);
    if (barnData['rows'] is List) {
      barnData['rows'] = jsonEncode(barnData['rows']);
    }
    await db.insert('barns', barnData, conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted barn: ${barn['name']}');
  }

  Future<void> updateBarn(Map<String, dynamic> barn) async {
    final db = await database;
    final barnData = Map<String, dynamic>.from(barn);
    if (barnData['rows'] is List) {
      barnData['rows'] = jsonEncode(barnData['rows']);
    }
    await db.update(
      'barns',
      barnData,
      where: 'id = ?',
      whereArgs: [
        barn['id']
      ],
    );
    print('✅ Updated barn: ${barn['name']}');
  }

  Future<List<Map<String, dynamic>>> getAllBarns() async {
    final db = await database;
    return await db.query('barns', orderBy: 'name ASC');
  }

  Future<void> deleteBarn(String id) async {
    final db = await database;
    await db.delete('barns', where: 'id = ?', whereArgs: [
      id
    ]);
    print('🗑️ Deleted barn: $id');
  }

  // ==================== BREEDS CRUD ====================

  /// Ensure breeds table exists (safety net for cached DB connections)
  Future<void> _ensureBreedsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS breeds(
        id TEXT PRIMARY KEY,
        name TEXT,
        genetics TEXT
      )
    ''');
  }

  Future<void> insertBreed(Breed breed) async {
    final db = await database;
    await _ensureBreedsTable(db);
    await db.insert('breeds', breed.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted breed: ${breed.name}');
  }

  Future<List<Breed>> getAllBreeds() async {
    final db = await database;
    await _ensureBreedsTable(db);
    final List<Map<String, dynamic>> maps = await db.query('breeds', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => Breed.fromMap(maps[i]));
  }

  Future<Breed?> getBreedByName(String name) async {
    final db = await database;
    await _ensureBreedsTable(db);
    final List<Map<String, dynamic>> maps = await db.query(
      'breeds',
      where: 'name = ?',
      whereArgs: [
        name
      ],
    );
    if (maps.isEmpty) return null;
    return Breed.fromMap(maps.first);
  }

  Future<void> updateBreed(Breed breed) async {
    final db = await database;
    await _ensureBreedsTable(db);
    await db.update(
      'breeds',
      breed.toMap(),
      where: 'id = ?',
      whereArgs: [
        breed.id
      ],
    );
    print('✅ Updated breed: ${breed.name}');
  }

  Future<void> deleteBreed(String id) async {
    final db = await database;
    await _ensureBreedsTable(db);
    await db.delete('breeds', where: 'id = ?', whereArgs: [
      id
    ]);
    print('🗑️ Deleted breed: $id');
  }

  /// Update genetics on all rabbits that have the given breed name
  Future<void> updateGeneticsForBreed(String breedName, String genetics) async {
    final db = await database;
    await db.update(
      'rabbits',
      {
        'genetics': genetics
      },
      where: 'breed = ?',
      whereArgs: [
        breedName
      ],
    );
    print('✅ Updated genetics for all rabbits with breed: $breedName');
  }

  /// Fix litters that have rabbit IDs in sire/dam fields instead of names.
  /// This handles litters created via logBirth before the fix.
  Future<void> fixLitterSireDamNames() async {
    final db = await database;
    final littersData = await db.query('litters');

    for (final litterMap in littersData) {
      final litter = Litter.fromMap(litterMap);
      bool needsUpdate = false;
      String newSire = litter.sire;
      String newDam = litter.dam;

      // Check if sire looks like a rabbit ID (e.g. "R-0001" or any ID format)
      // If sire != buckName and buckId exists, look up the actual name
      if (litter.buckId.isNotEmpty && (litter.sire == litter.buckId || litter.sire.isEmpty)) {
        final buck = await getRabbit(litter.buckId);
        if (buck != null && buck.name.isNotEmpty) {
          newSire = buck.name;
          needsUpdate = true;
        }
      }

      // Check if dam looks like a rabbit ID
      if (litter.doeId.isNotEmpty && (litter.dam == litter.doeId || litter.dam.isEmpty)) {
        final doe = await getRabbit(litter.doeId);
        if (doe != null && doe.name.isNotEmpty) {
          newDam = doe.name;
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        await db.update(
          'litters',
          {
            'sire': newSire,
            'dam': newDam
          },
          where: 'id = ?',
          whereArgs: [
            litter.id
          ],
        );
        print('✅ Fixed sire/dam for litter ${litter.id}: sire=$newSire, dam=$newDam');
      }
    }
  }

  // ==================== TRANSACTIONS (FINANCE) ====================

  /// Remove duplicate pipeline tasks — keeps only one task per litter+taskType or rabbit+taskType
  Future<void> _deduplicatePipelineTasks(Database db) async {
    int removed = 0;

    // Deduplicate by litterId + taskType (for wean tasks)
    final litterTasks = await db.rawQuery('''
      SELECT litterId, taskType, GROUP_CONCAT(id) as ids, COUNT(*) as cnt
      FROM tasks
      WHERE litterId IS NOT NULL AND litterId != ''
      GROUP BY litterId, taskType
      HAVING cnt > 1
    ''');

    for (final row in litterTasks) {
      final ids = (row['ids'] as String).split(',');
      // Keep the first one, delete the rest
      for (int i = 1; i < ids.length; i++) {
        await db.delete('tasks', where: 'id = ?', whereArgs: [
          ids[i]
        ]);
        removed++;
      }
    }

    // Deduplicate by rabbitId + taskType (for palpation, kindle, etc.)
    final rabbitTasks = await db.rawQuery('''
      SELECT rabbitId, taskType, GROUP_CONCAT(id) as ids, COUNT(*) as cnt
      FROM tasks
      WHERE rabbitId IS NOT NULL AND rabbitId != '' AND (litterId IS NULL OR litterId = '')
      GROUP BY rabbitId, taskType
      HAVING cnt > 1
    ''');

    for (final row in rabbitTasks) {
      final ids = (row['ids'] as String).split(',');
      for (int i = 1; i < ids.length; i++) {
        await db.delete('tasks', where: 'id = ?', whereArgs: [
          ids[i]
        ]);
        removed++;
      }
    }

    if (removed > 0) {
      print('🧹 Removed $removed duplicate pipeline tasks');
    }
  }

  /// Backfill missing pipeline tasks for existing rabbits/litters that were created
  /// without going through the breeding pipeline (e.g., added via Add Litter form).
  Future<void> backfillMissingPipelineTasks() async {
    final db = await database;
    int created = 0;

    // Clean up duplicate pipeline tasks (keep only one per litter/rabbit+taskType)
    await _deduplicatePipelineTasks(db);

    // 1. Nursing litters without a wean task
    final litters = await db.query('litters');
    for (final litter in litters) {
      final status = (litter['status'] ?? '').toString().toLowerCase();
      if (status != 'nursing') continue;

      final litterId = litter['id']?.toString() ?? '';
      final doeId = litter['doeId']?.toString() ?? '';

      // Check if a wean task already exists for this litter (completed or not)
      final existing = await db.query(
        'tasks',
        where: 'litterId = ? AND taskType = ?',
        whereArgs: [
          litterId,
          'wean'
        ],
      );
      if (existing.isNotEmpty) continue;

      // Create wean task
      final weanDate = litter['weanDate']?.toString();
      final dueDate = weanDate ?? DateTime.now().add(Duration(days: 28)).toIso8601String();
      final aliveKits = litter['currentAlive'] ?? litter['aliveKits'] ?? 0;

      await insertTask({
        'id': 'task_wean_backfill_${litterId}_${DateTime.now().millisecondsSinceEpoch}',
        'rabbitId': doeId,
        'litterId': litterId,
        'title': 'Wean Litter',
        'description': '$aliveKits kits ready for weaning',
        'taskType': 'wean',
        'dueDate': dueDate,
        'completed': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      created++;
    }

    // 2. Does with palpateDue status but no palpation task
    final rabbits = await db.query('rabbits');
    for (final rabbit in rabbits) {
      final statusStr = rabbit['status']?.toString() ?? '';
      final rabbitId = rabbit['id']?.toString() ?? '';

      if (statusStr.contains('palpateDue')) {
        final existing = await db.query(
          'tasks',
          where: 'rabbitId = ? AND taskType = ?',
          whereArgs: [
            rabbitId,
            'palpation'
          ],
        );
        if (existing.isEmpty) {
          final palpDate = rabbit['palpationDate']?.toString() ?? DateTime.now().toIso8601String();
          await insertTask({
            'id': 'task_palp_backfill_${rabbitId}_${DateTime.now().millisecondsSinceEpoch}',
            'rabbitId': rabbitId,
            'title': 'Palpation Check',
            'description': 'Pregnancy check',
            'taskType': 'palpation',
            'dueDate': palpDate,
            'completed': 0,
            'createdAt': DateTime.now().toIso8601String(),
          });
          created++;
        }
      } else if (statusStr.contains('pregnant')) {
        // Does marked pregnant but no kindle task
        final existing = await db.query(
          'tasks',
          where: 'rabbitId = ? AND taskType IN (?, ?)',
          whereArgs: [
            rabbitId,
            'kindle',
            'nestbox'
          ],
        );
        if (existing.isEmpty) {
          final dueDate = rabbit['dueDate']?.toString() ?? DateTime.now().add(Duration(days: 31)).toIso8601String();
          await insertTask({
            'id': 'task_kindle_backfill_${rabbitId}_${DateTime.now().millisecondsSinceEpoch}',
            'rabbitId': rabbitId,
            'title': 'Expected Kindle',
            'description': 'Due date for birth',
            'taskType': 'kindle',
            'dueDate': dueDate,
            'completed': 0,
            'createdAt': DateTime.now().toIso8601String(),
          });
          created++;
        }
      }
    }

    if (created > 0) {
      print('✅ Backfilled $created missing pipeline tasks');
    }
  }

  /// Backfill finance transactions for sold kits and sold rabbits that are missing transactions.
  /// This handles data created before the sell flow was fixed to auto-create transactions.
  Future<void> backfillSoldTransactions() async {
    final db = await database;

    // 1. Backfill sold KITS from litters
    final littersData = await db.query('litters');
    for (final litterMap in littersData) {
      final litter = Litter.fromMap(litterMap);
      for (final kit in litter.kits) {
        if (kit.status == 'Sold' && kit.price != null && kit.price! > 0) {
          // Check if a transaction already exists for this kit
          final existing = await db.query(
            'transactions',
            where: 'kitId = ? AND litterId = ? AND category = ?',
            whereArgs: [
              kit.id.toString(),
              litter.id,
              'TransactionCategory.soldKit'
            ],
          );
          if (existing.isEmpty) {
            final transaction = finance_model.Transaction(
              id: 'txn_backfill_kit_${litter.id}_${kit.id}',
              type: finance_model.TransactionType.income,
              category: finance_model.TransactionCategory.soldKit,
              amount: kit.price!,
              date: DateTime.now(),
              description: 'Sold Kit ${litter.id}-${kit.id}',
              notes: kit.details?.isNotEmpty == true ? kit.details : null,
              linkType: finance_model.LinkType.litter,
              litterId: litter.id,
              kitId: kit.id.toString(),
              kitColor: kit.color,
              kitSex: kit.sex,
              buyerInfo: kit.details?.replaceFirst('Sold to ', ''),
            );
            await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
            print('✅ Backfilled transaction for sold kit ${litter.id}-${kit.id}: ${kit.price}');
          }
        }
      }
    }

    // 2. Backfill sold RABBITS
    final soldRabbits = await db.query(
      'rabbits',
      where: 'archiveReason = ? AND salePrice IS NOT NULL AND salePrice > 0',
      whereArgs: [
        'ArchiveReason.sold'
      ],
    );
    for (final rabbitMap in soldRabbits) {
      final rabbitId = rabbitMap['id'] as String;
      final salePrice = (rabbitMap['salePrice'] as num).toDouble();
      final rabbitName = rabbitMap['name'] as String? ?? rabbitId;
      final buyerInfo = rabbitMap['buyerInfo'] as String?;

      // Check if a transaction already exists for this rabbit sale
      final existing = await db.query(
        'transactions',
        where: 'rabbitId = ? AND category = ?',
        whereArgs: [
          rabbitId,
          'TransactionCategory.soldKit'
        ],
      );
      if (existing.isEmpty) {
        final transaction = finance_model.Transaction(
          id: 'txn_backfill_rabbit_$rabbitId',
          type: finance_model.TransactionType.income,
          category: finance_model.TransactionCategory.soldKit,
          amount: salePrice,
          date: rabbitMap['archiveDate'] != null ? DateTime.parse(rabbitMap['archiveDate'] as String) : DateTime.now(),
          description: 'Sold $rabbitName ($rabbitId)',
          notes: buyerInfo != null ? 'Buyer: $buyerInfo' : null,
          linkType: finance_model.LinkType.rabbit,
          rabbitId: rabbitId,
          buyerInfo: buyerInfo,
        );
        await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
        print('✅ Backfilled transaction for sold rabbit $rabbitId: $salePrice');
      }
    }
  }

  Future<void> insertTransaction(finance_model.Transaction transaction) async {
    final db = await database;
    await db.insert('transactions', transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted transaction: ${transaction.categoryName} - \$${transaction.amount}');
  }

  Future<void> updateTransaction(finance_model.Transaction transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [
        transaction.id
      ],
    );
    print('✅ Updated transaction: ${transaction.id}');
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [
      id
    ]);
    print('🗑️ Deleted transaction: $id');
  }

  Future<List<finance_model.Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<finance_model.Transaction?> getTransactionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
    if (maps.isEmpty) return null;
    return finance_model.Transaction.fromMap(maps.first);
  }

  Future<List<finance_model.Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String()
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<List<finance_model.Transaction>> getTransactionsByRabbit(String rabbitId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'rabbitId = ?',
      whereArgs: [
        rabbitId
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<List<finance_model.Transaction>> getTransactionsByLitter(String litterId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'litterId = ?',
      whereArgs: [
        litterId
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<List<finance_model.Transaction>> getTransactionsByCategory(finance_model.TransactionCategory category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [
        category.toString()
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<List<finance_model.Transaction>> getTransactionsByType(finance_model.TransactionType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [
        type.toString()
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<List<finance_model.Transaction>> getTransactionsByBatch(String batchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'batchId = ?',
      whereArgs: [
        batchId
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => finance_model.Transaction.fromMap(maps[i]));
  }

  Future<Map<String, double>> getFinanceSummary({DateTime? start, DateTime? end}) async {
    final transactions = start != null && end != null ? await getTransactionsByDateRange(start, end) : await getAllTransactions();

    double income = 0;
    double expense = 0;

    for (var t in transactions) {
      if (t.type == finance_model.TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'net': income - expense,
    };
  }

  Future<Map<String, double>> getFinanceSummaryByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return await getFinanceSummary(start: start, end: end);
  }

  Future<Map<finance_model.TransactionCategory, double>> getCategorySummary({
    DateTime? start,
    DateTime? end,
    finance_model.TransactionType? type,
  }) async {
    var transactions = start != null && end != null ? await getTransactionsByDateRange(start, end) : await getAllTransactions();

    if (type != null) {
      transactions = transactions.where((t) => t.type == type).toList();
    }

    Map<finance_model.TransactionCategory, double> summary = {};

    for (var t in transactions) {
      summary[t.category] = (summary[t.category] ?? 0) + t.amount;
    }

    return summary;
  }

  Future<double> getTotalByRabbit(String rabbitId) async {
    final transactions = await getTransactionsByRabbit(rabbitId);
    double total = 0;
    for (var t in transactions) {
      if (t.type == finance_model.TransactionType.income) {
        total += t.amount;
      } else {
        total -= t.amount;
      }
    }
    return total;
  }

  Future<double> getTotalByLitter(String litterId) async {
    final transactions = await getTransactionsByLitter(litterId);
    double total = 0;
    for (var t in transactions) {
      if (t.type == finance_model.TransactionType.income) {
        total += t.amount;
      } else {
        total -= t.amount;
      }
    }
    return total;
  }

  // ==================== SCHEDULED TASKS CRUD ====================

  /// Ensure scheduled_tasks table exists with all columns including completedAt
  Future<void> _ensureScheduledTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scheduled_tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        frequency TEXT NOT NULL,
        linkType TEXT NOT NULL,
        linkedEntities TEXT,
        dueDate TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        completedAt TEXT
      )
    ''');
    // Also try adding the column if table existed without it
    try {
      await db.execute('ALTER TABLE scheduled_tasks ADD COLUMN completedAt TEXT');
    } catch (_) {}
  }

  /// Cleanup tasks completed before today:
  /// - One-time: delete
  /// - Recurring: reschedule to next due date and clear completedAt
  Future<void> cleanupCompletedScheduledTasks() async {
    final db = await database;
    await _ensureScheduledTasksTable(db);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    // Get all tasks completed before today
    final completed = await db.query(
      'scheduled_tasks',
      where: 'completedAt IS NOT NULL AND completedAt < ?',
      whereArgs: [
        todayStart
      ],
    );

    for (final task in completed) {
      final id = task['id'] as int;
      final frequency = task['frequency']?.toString() ?? 'Once';

      if (frequency == 'Once' || frequency == 'One-time') {
        // One-time task completed yesterday or before → delete
        await db.delete('scheduled_tasks', where: 'id = ?', whereArgs: [
          id
        ]);
      } else {
        // Recurring task → advance due date past today, clear completedAt
        final currentDue = DateTime.tryParse(task['dueDate']?.toString() ?? '') ?? now;
        DateTime nextDue = _calculateNextRecurringDate(frequency, currentDue);
        // Keep advancing until nextDue is today or later
        while (nextDue.isBefore(DateTime(now.year, now.month, now.day))) {
          nextDue = _calculateNextRecurringDate(frequency, nextDue);
        }
        await db.update(
          'scheduled_tasks',
          {
            'dueDate': nextDue.toIso8601String(),
            'completedAt': null
          },
          where: 'id = ?',
          whereArgs: [
            id
          ],
        );
      }
    }

    // Also cleanup pipeline tasks completed before today
    await _ensureTasksIgnoredColumn(db);
    await db.delete(
      'tasks',
      where: 'completed = 1 AND completedAt IS NOT NULL AND completedAt < ?',
      whereArgs: [
        todayStart
      ],
    );

    if (completed.isNotEmpty) {
      print('✅ Cleaned up ${completed.length} completed scheduled tasks from previous days');
    }
  }

  DateTime _calculateNextRecurringDate(String frequency, DateTime from) {
    switch (frequency) {
      case 'Daily':
        return from.add(Duration(days: 1));
      case 'Weekly':
        return from.add(Duration(days: 7));
      case 'Bi-Weekly':
        return from.add(Duration(days: 14));
      case 'Monthly':
        return DateTime(from.year, from.month + 1, from.day);
      case 'Quarterly':
        return DateTime(from.year, from.month + 3, from.day);
      case 'Semi-Annually':
        return DateTime(from.year, from.month + 6, from.day);
      case 'Annually':
        return DateTime(from.year + 1, from.month, from.day);
      default:
        return from.add(Duration(days: 7));
    }
  }

  /// Mark a scheduled task as completed (keeps it visible until day ends)
  Future<void> markScheduledTaskCompleted(int id) async {
    final db = await database;
    await db.update(
      'scheduled_tasks',
      {
        'completedAt': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
  }

  /// Unmark a scheduled task as completed (user unchecked the box)
  Future<void> unmarkScheduledTaskCompleted(int id) async {
    final db = await database;
    await db.update(
      'scheduled_tasks',
      {
        'completedAt': null
      },
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
  }

  Future<int> insertScheduledTask(Map<String, dynamic> task) async {
    final db = await database;
    await _ensureScheduledTasksTable(db);

    final Map<String, dynamic> taskData = {
      'name': task['name'] ?? task['task'] ?? 'Unknown Task',
      'category': task['category'] ?? 'Operations',
      'frequency': task['frequency'] ?? 'Weekly',
      'linkType': task['linkType'] ?? 'unlinked',
      'linkedEntities': task['linkedEntities'] is String ? task['linkedEntities'] : json.encode(task['linkedEntities'] ?? []),
      'dueDate': task['dueDate'] ?? _calculateNextDueDate(task['frequency'] ?? 'Weekly'),
      'createdAt': task['createdAt'] ?? DateTime.now().toIso8601String(),
    };

    final id = await db.insert('scheduled_tasks', taskData);
    print('✅ Inserted scheduled task: ${taskData['name']} with id: $id');
    return id;
  }

  String _calculateNextDueDate(String frequency) {
    final now = DateTime.now();
    DateTime dueDate;

    // ✅ Set initial due date to TODAY so tasks appear immediately
    // The frequency determines when the NEXT occurrence will be after completion
    switch (frequency) {
      case 'Daily':
        dueDate = now;
        break;
      case 'Weekly':
        dueDate = now; // Show today, next occurrence in 7 days after completion
        break;
      case 'Bi-Weekly':
        dueDate = now; // Show today, next occurrence in 14 days after completion
        break;
      case 'Monthly':
        dueDate = now; // Show today, next occurrence in 1 month after completion
        break;
      case 'Once':
      case 'One-time':
        dueDate = now;
        break;
      default:
        dueDate = now;
    }

    return dueDate.toIso8601String();
  }

  Future<List<Map<String, dynamic>>> getAllScheduledTasks() async {
    final db = await database;
    await _ensureScheduledTasksTable(db);

    final List<Map<String, dynamic>> maps = await db.query(
      'scheduled_tasks',
      orderBy: 'dueDate ASC',
    );

    print('📋 getAllScheduledTasks: Found ${maps.length} tasks in database');

    return maps.map((task) {
      return {
        'id': task['id'],
        'task': task['name'],
        'name': task['name'],
        'category': task['category'],
        'frequency': task['frequency'],
        'linkType': task['linkType'],
        'linkedEntities': task['linkedEntities'] != null ? json.decode(task['linkedEntities'] as String) : [],
        'dueDate': task['dueDate'],
        'createdAt': task['createdAt'],
        'completedAt': task['completedAt'],
      };
    }).toList();
  }

  Future<void> deleteScheduledTask(int id) async {
    final db = await database;
    await db.delete(
      'scheduled_tasks',
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
    print('✅ Deleted scheduled task with id: $id');
  }

  Future<List<Map<String, dynamic>>> getTasksDueToday({bool snowballEffect = true}) async {
    final db = await database;
    await _ensureScheduledTasksTable(db);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Include tasks due today (and overdue if snowball is on) that are NOT completed,
    // PLUS tasks completed today (so they stay visible with a checkmark)
    final List<Map<String, dynamic>> maps;
    if (snowballEffect) {
      // Snowball ON: show overdue + today
      maps = await db.query(
        'scheduled_tasks',
        where: 'dueDate <= ? AND (completedAt IS NULL OR completedAt >= ?)',
        whereArgs: [
          todayEnd.toIso8601String(),
          todayStart.toIso8601String(),
        ],
        orderBy: 'dueDate ASC',
      );
    } else {
      // Snowball OFF: only show tasks due today (not overdue)
      maps = await db.query(
        'scheduled_tasks',
        where: 'dueDate >= ? AND dueDate <= ? AND (completedAt IS NULL OR completedAt >= ?)',
        whereArgs: [
          todayStart.toIso8601String(),
          todayEnd.toIso8601String(),
          todayStart.toIso8601String(),
        ],
        orderBy: 'dueDate ASC',
      );
    }

    print('📋 getTasksDueToday: Found ${maps.length} tasks due today/overdue');

    return maps.map((task) {
      return {
        'id': task['id'],
        'task': task['name'],
        'name': task['name'],
        'category': task['category'],
        'frequency': task['frequency'],
        'linkType': task['linkType'],
        'linkedEntities': task['linkedEntities'] != null ? json.decode(task['linkedEntities'] as String) : [],
        'dueDate': task['dueDate'],
        'createdAt': task['createdAt'],
        'completedAt': task['completedAt'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUpcomingScheduledTasks() async {
    final db = await database;
    await _ensureScheduledTasksTable(db);

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'scheduled_tasks',
      where: 'dueDate > ? AND (completedAt IS NULL OR completedAt >= ?)',
      whereArgs: [
        todayEnd.toIso8601String(),
        todayStart,
      ],
      orderBy: 'dueDate ASC',
    );

    return maps.map((task) {
      return {
        'id': task['id'],
        'task': task['name'],
        'name': task['name'],
        'category': task['category'],
        'frequency': task['frequency'],
        'linkType': task['linkType'],
        'linkedEntities': task['linkedEntities'] != null ? json.decode(task['linkedEntities'] as String) : [],
        'dueDate': task['dueDate'],
        'createdAt': task['createdAt'],
        'completedAt': task['completedAt'],
      };
    }).toList();
  }

  Future<void> updateScheduledTaskDueDate(int id, String newDueDate) async {
    final db = await database;
    await db.update(
      'scheduled_tasks',
      {
        'dueDate': newDueDate
      },
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
    print('✅ Updated due date for scheduled task id: $id');
  }

  /// Get all scheduled tasks linked to a specific rabbit by ID.
  /// Returns tasks where linkType='rabbit' and linkedEntities contains the rabbitId.
  Future<List<Map<String, dynamic>>> getScheduledTasksByRabbit(String rabbitId) async {
    final db = await database;
    await _ensureScheduledTasksTable(db);

    // Get all tasks that are linked to rabbits
    final List<Map<String, dynamic>> rabbitTasks = await db.query(
      'scheduled_tasks',
      where: "linkType = 'rabbit'",
      orderBy: 'dueDate ASC',
    );

    // Filter to only tasks whose linkedEntities contain this rabbit's ID
    final filtered = rabbitTasks.where((task) {
      try {
        final entities = task['linkedEntities'] != null ? json.decode(task['linkedEntities'] as String) : [];
        if (entities is List) {
          return entities.any((e) {
            if (e is Map) return e['id'] == rabbitId;
            if (e is String) return e == rabbitId;
            return false;
          });
        }
      } catch (_) {}
      return false;
    }).toList();

    // Also get litter-linked tasks where this rabbit is the doe
    final litterTasks = await db.query(
      'scheduled_tasks',
      where: "linkType = 'litter'",
      orderBy: 'dueDate ASC',
    );

    // Find litters belonging to this rabbit (as doe)
    final litters = await db.query('litters', where: 'doeId = ?', whereArgs: [
      rabbitId
    ]);
    final litterIds = litters.map((l) => l['id']?.toString()).where((id) => id != null).toSet();

    final litterFiltered = litterTasks.where((task) {
      try {
        final entities = task['linkedEntities'] != null ? json.decode(task['linkedEntities'] as String) : [];
        if (entities is List) {
          return entities.any((e) {
            if (e is Map) return litterIds.contains(e['id']?.toString());
            if (e is String) return litterIds.contains(e);
            return false;
          });
        }
      } catch (_) {}
      return false;
    }).toList();

    final allFiltered = [
      ...filtered,
      ...litterFiltered
    ];

    print('📋 getScheduledTasksByRabbit($rabbitId): Found ${filtered.length} rabbit-linked + ${litterFiltered.length} litter-linked tasks');

    return allFiltered.map((task) {
      return {
        'id': task['id'],
        'task': task['name'],
        'name': task['name'],
        'category': task['category'],
        'frequency': task['frequency'],
        'linkType': task['linkType'],
        'linkedEntities': task['linkedEntities'] != null ? json.decode(task['linkedEntities'] as String) : [],
        'dueDate': task['dueDate'],
        'createdAt': task['createdAt'],
        'completedAt': task['completedAt'],
      };
    }).toList();
  }

  // ==================== TASK DIRECTORY ====================

  Future<void> _ensureTaskDirectoryTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_directory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertTaskDirectoryItem(String name, String category) async {
    await _ensureTaskDirectoryTable();
    final db = await database;
    final id = await db.insert('task_directory', {
      'name': name,
      'category': category,
      'createdAt': DateTime.now().toIso8601String(),
    });
    print('✅ Inserted task directory item: $name ($category)');
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllTaskDirectoryItems() async {
    await _ensureTaskDirectoryTable();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'task_directory',
      orderBy: 'category ASC, name ASC',
    );
    return maps;
  }

  Future<List<Map<String, dynamic>>> getTaskDirectoryByCategory(String category) async {
    await _ensureTaskDirectoryTable();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'task_directory',
      where: 'category = ?',
      whereArgs: [
        category
      ],
      orderBy: 'name ASC',
    );
    return maps;
  }

  Future<void> deleteTaskDirectoryItem(int id) async {
    await _ensureTaskDirectoryTable();
    final db = await database;
    await db.delete(
      'task_directory',
      where: 'id = ?',
      whereArgs: [
        id
      ],
    );
    print('✅ Deleted task directory item with id: $id');
  }

  // ✅ Add this method to migrate existing tables
  Future<void> _migrateLittersTable(Database db) async {
    try {
      // Check if columns exist, add them if missing
      final columns = await db.rawQuery("PRAGMA table_info(litters)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (!columnNames.contains('dob')) {
        await db.execute('ALTER TABLE litters ADD COLUMN dob TEXT');
        print('✅ Added dob column');
      }
      if (!columnNames.contains('location')) {
        await db.execute('ALTER TABLE litters ADD COLUMN location TEXT');
        print('✅ Added location column');
      }
      if (!columnNames.contains('cage')) {
        await db.execute('ALTER TABLE litters ADD COLUMN cage TEXT');
        print('✅ Added cage column');
      }
      if (!columnNames.contains('breed')) {
        await db.execute('ALTER TABLE litters ADD COLUMN breed TEXT');
        print('✅ Added breed column');
      }
      if (!columnNames.contains('status')) {
        await db.execute('ALTER TABLE litters ADD COLUMN status TEXT');
        print('✅ Added status column');
      }
      if (!columnNames.contains('sire')) {
        await db.execute('ALTER TABLE litters ADD COLUMN sire TEXT');
        print('✅ Added sire column');
      }
      if (!columnNames.contains('dam')) {
        await db.execute('ALTER TABLE litters ADD COLUMN dam TEXT');
        print('✅ Added dam column');
      }
      if (!columnNames.contains('kits')) {
        await db.execute('ALTER TABLE litters ADD COLUMN kits TEXT');
        print('✅ Added kits column');
      }

      print('✅ Litters table migration complete');
    } catch (e) {
      print('❌ Error migrating litters table: $e');
    }
  }

  // ==================== DOCUMENTS CRUD ====================

  Future<void> insertDocument(RabbitDocument doc) async {
    final db = await database;
    await db.insert('documents', doc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    print('✅ Inserted document: ${doc.name}');
  }

  Future<List<RabbitDocument>> getDocumentsByRabbit(String rabbitId) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: 'rabbitId = ?',
      whereArgs: [
        rabbitId
      ],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => RabbitDocument.fromMap(m)).toList();
  }

  Future<void> updateDocument(RabbitDocument doc) async {
    final db = await database;
    await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [
        doc.id
      ],
    );
    print('✅ Updated document: ${doc.name}');
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete('documents', where: 'id = ?', whereArgs: [
      id
    ]);
    print('✅ Deleted document: $id');
  }
}
