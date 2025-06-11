const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const agencyRoutes = require('./routes/agency');
const customerRoutes = require('./routes/customer');

require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/agency', agencyRoutes);
app.use('/api/customer', customerRoutes);

const PORT = process.env.PORT || 5000;

mongoose.connect(process.env.MONGO_URI, {useNewUrlParser: true, useUnifiedTopology: true})
.then(() => {
    app.listen(PORT, () => console.log(`Server started on port ${PORT}`));
})
.catch((err) => console.log("MongoDB connection error:", err));