import express from 'express';
import admin from 'firebase-admin';

const app = express();
app.use(express.json());

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'mychannel-ca26d'
  });
}

const db = admin.firestore();

async function requireUser(req: any, res: any) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return null;
    }

    const token = authHeader.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(token);
    return { userId: decoded.uid, email: decoded.email };
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tax Forms (W-9 Collection)
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/artists/:artistId/tax-form - Submit W-9 tax form
app.post('/v1/music/artists/:artistId/tax-form', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { legalName, businessName, taxId, address, city, state, zip, country, signature } = req.body || {};

    if (!legalName) {
      return res.status(400).json({ error: 'legalName is required' });
    }

    if (!taxId) {
      return res.status(400).json({ error: 'taxId (SSN/EIN) is required' });
    }

    if (!address || !city || !state || !zip || !country) {
      return res.status(400).json({ error: 'Complete address is required' });
    }

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const taxFormRef = db.collection('artist_tax_forms').doc(artistId);

    await taxFormRef.set({
      artistId,
      legalName,
      businessName: businessName || null,
      taxId,
      address,
      city,
      state,
      zip,
      country,
      signature,
      submittedAt: now,
      status: 'submitted'
    });

    res.status(201).json({
      artistId,
      status: 'submitted',
      message: 'W-9 tax form submitted successfully'
    });
  } catch (error) {
    console.error('Submit tax form error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/artists/:artistId/tax-form - Get tax form status
app.get('/v1/music/artists/:artistId/tax-form', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const taxFormRef = db.collection('artist_tax_forms').doc(artistId);
    const taxFormSnap = await taxFormRef.get();

    if (!taxFormSnap.exists) {
      return res.status(404).json({ error: 'Tax form not submitted' });
    }

    const data = taxFormSnap.data()!;

    res.json({
      artistId,
      status: data.status,
      submittedAt: data.submittedAt?.toDate().toISOString()
    });
  } catch (error) {
    console.error('Get tax form error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Label Management (Multiple Artist Accounts)
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/labels - Create label
app.post('/v1/music/labels', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { name, description, logoURL } = req.body || {};

    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }

    const now = admin.firestore.Timestamp.now();
    const labelRef = db.collection('music_labels').doc();

    await labelRef.set({
      id: labelRef.id,
      ownerId: user.userId,
      name: name.trim(),
      description: description || null,
      logoURL: logoURL || null,
      createdAt: now
    });

    res.status(201).json({
      labelId: labelRef.id,
      name,
      message: 'Label created successfully'
    });
  } catch (error) {
    console.error('Create label error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/labels/:labelId/artists - Add artist to label
app.post('/v1/music/labels/:labelId/artists', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { labelId } = req.params;
    const { artistId } = req.body || {};

    if (!artistId) {
      return res.status(400).json({ error: 'artistId is required' });
    }

    const labelRef = db.collection('music_labels').doc(labelId);
    const labelSnap = await labelRef.get();

    if (!labelSnap.exists) {
      return res.status(404).json({ error: 'Label not found' });
    }

    const labelData = labelSnap.data()!;

    if (String(labelData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const labelArtistRef = db.collection('label_artists').doc();

    await labelArtistRef.set({
      id: labelArtistRef.id,
      labelId,
      artistId,
      addedAt: now
    });

    res.status(201).json({
      labelArtistId: labelArtistRef.id,
      message: 'Artist added to label successfully'
    });
  } catch (error) {
    console.error('Add artist to label error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/labels/:labelId/dashboard - Label dashboard
app.get('/v1/music/labels/:labelId/dashboard', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { labelId } = req.params;

    const labelRef = db.collection('music_labels').doc(labelId);
    const labelSnap = await labelRef.get();

    if (!labelSnap.exists) {
      return res.status(404).json({ error: 'Label not found' });
    }

    const labelData = labelSnap.data()!;

    if (String(labelData.ownerId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Get label artists
    const labelArtistsSnap = await db.collection('label_artists')
      .where('labelId', '==', labelId)
      .get();

    const artistIds = labelArtistsSnap.docs.map(doc => doc.data().artistId);

    // Get all tracks from label artists
    const tracksSnap = await db.collection('music_tracks')
      .where('artistId', 'in', artistIds.slice(0, 10))
      .get();

    let totalStreams = 0;
    tracksSnap.docs.forEach(doc => {
      totalStreams += doc.data().streamCount || 0;
    });

    const dashboard = {
      labelId,
      name: labelData.name,
      totalArtists: artistIds.length,
      totalTracks: tracksSnap.size,
      totalStreams,
      totalEarnings: totalStreams * 0.004
    };

    res.json({ dashboard });
  } catch (error) {
    console.error('Label dashboard error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Merch Integration
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/artists/:artistId/merch - Create merch item
app.post('/v1/music/artists/:artistId/merch', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { name, description, price, imageURL, stock } = req.body || {};

    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }

    if (typeof price !== 'number' || price < 0) {
      return res.status(400).json({ error: 'price must be a non-negative number' });
    }

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const merchRef = db.collection('artist_merch').doc();

    await merchRef.set({
      id: merchRef.id,
      artistId,
      name: name.trim(),
      description: description || null,
      price,
      imageURL: imageURL || null,
      stock: stock || 0,
      sold: 0,
      status: 'active',
      createdAt: now
    });

    res.status(201).json({
      merchId: merchRef.id,
      name,
      price,
      message: 'Merch item created successfully'
    });
  } catch (error) {
    console.error('Create merch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/artists/:artistId/merch - List merch items
app.get('/v1/music/artists/:artistId/merch', async (req, res) => {
  try {
    const { artistId } = req.params;

    const merchSnap = await db.collection('artist_merch')
      .where('artistId', '==', artistId)
      .where('status', '==', 'active')
      .orderBy('createdAt', 'desc')
      .get();

    const merch = merchSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name,
        description: data.description,
        price: data.price,
        imageURL: data.imageURL,
        stock: data.stock,
        sold: data.sold
      };
    });

    res.json({
      artistId,
      merch,
      total: merchSnap.size
    });
  } catch (error) {
    console.error('List merch error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Tour/Concert Management
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/artists/:artistId/tours - Create tour
app.post('/v1/music/artists/:artistId/tours', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { name, startDate, endDate, description } = req.body || {};

    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const tourRef = db.collection('artist_tours').doc();

    await tourRef.set({
      id: tourRef.id,
      artistId,
      name: name.trim(),
      startDate: startDate ? admin.firestore.Timestamp.fromDate(new Date(startDate)) : null,
      endDate: endDate ? admin.firestore.Timestamp.fromDate(new Date(endDate)) : null,
      description: description || null,
      status: 'upcoming',
      createdAt: now
    });

    res.status(201).json({
      tourId: tourRef.id,
      name,
      message: 'Tour created successfully'
    });
  } catch (error) {
    console.error('Create tour error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/tours/:tourId/dates - Add tour date
app.post('/v1/music/tours/:tourId/dates', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { tourId } = req.params;
    const { venue, city, date, ticketPrice, ticketURL } = req.body || {};

    if (!venue || !city || !date) {
      return res.status(400).json({ error: 'venue, city, and date are required' });
    }

    const tourRef = db.collection('artist_tours').doc(tourId);
    const tourSnap = await tourRef.get();

    if (!tourSnap.exists) {
      return res.status(404).json({ error: 'Tour not found' });
    }

    const tourData = tourSnap.data()!;

    if (String(tourData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const tourDateRef = db.collection('tour_dates').doc();

    await tourDateRef.set({
      id: tourDateRef.id,
      tourId,
      venue,
      city,
      date: admin.firestore.Timestamp.fromDate(new Date(date)),
      ticketPrice: ticketPrice || null,
      ticketURL: ticketURL || null,
      createdAt: now
    });

    res.status(201).json({
      tourDateId: tourDateRef.id,
      venue,
      city,
      date,
      message: 'Tour date added successfully'
    });
  } catch (error) {
    console.error('Add tour date error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/artists/:artistId/tours - List artist tours
app.get('/v1/music/artists/:artistId/tours', async (req, res) => {
  try {
    const { artistId } = req.params;

    const toursSnap = await db.collection('artist_tours')
      .where('artistId', '==', artistId)
      .orderBy('startDate', 'desc')
      .get();

    const tours = toursSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name,
        startDate: data.startDate?.toDate().toISOString(),
        endDate: data.endDate?.toDate().toISOString(),
        status: data.status
      };
    });

    res.json({
      artistId,
      tours,
      total: toursSnap.size
    });
  } catch (error) {
    console.error('List tours error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Email Notifications
// ─────────────────────────────────────────────────────────────────────────────

// PUT /v1/music/artists/:artistId/notifications - Update notification preferences
app.put('/v1/music/artists/:artistId/notifications', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { artistId } = req.params;
    const { newStreams, payouts, milestones, comments, collaborations } = req.body || {};

    if (user.userId !== artistId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const now = admin.firestore.Timestamp.now();
    const notifRef = db.collection('artist_notification_preferences').doc(artistId);

    await notifRef.set({
      artistId,
      newStreams: newStreams !== undefined ? newStreams : true,
      payouts: payouts !== undefined ? payouts : true,
      milestones: milestones !== undefined ? milestones : true,
      comments: comments !== undefined ? comments : true,
      collaborations: collaborations !== undefined ? collaborations : true,
      updatedAt: now
    }, { merge: true });

    res.json({
      artistId,
      message: 'Notification preferences updated successfully'
    });
  } catch (error) {
    console.error('Update notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8088;
app.listen(PORT, () => {
  console.log(`🎵 Music business service listening on port ${PORT}`);
});
