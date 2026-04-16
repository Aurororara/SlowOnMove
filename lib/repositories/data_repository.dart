import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/training_log_model.dart';

class DataRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==== Users ====
  
  /// Create or update a user profile
  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
  }

  /// Get a user profile by ID
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  // ==== Training Logs ====
  
  /// Save a training log for a user
  Future<void> saveTrainingLog(TrainingLogModel log) async {
    // Create reference to users/{uid}/training_logs
    final collection = _firestore
        .collection('users')
        .doc(log.memberId)
        .collection('training_logs');
        
    await collection.add(log.toJson());
  }

  /// Get past training logs (e.g. for history screen)
  Future<List<TrainingLogModel>> getUserTrainingHistory(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('training_logs')
        .orderBy('start_time', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TrainingLogModel.fromJson(doc.data(), doc.id))
        .toList();
  }
}
