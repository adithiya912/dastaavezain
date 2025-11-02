/* eslint-disable max-len */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// ========== DOCUMENT SCANNER FUNCTIONS ==========

// Function 1: Analyze Document (Original - for Scanner)
exports.analyzeDocument = onCall({ enforceAppCheck: true }, async (request) => {
  const imageUrl = request.data.imageUrl;

  if (!imageUrl) {
    console.error("Function called without an imageUrl.");
    throw new HttpsError(
      "invalid-argument",
      "Image URL is required."
    );
  }

  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }
    const imageBuffer = await response.arrayBuffer();
    const base64Image = Buffer.from(imageBuffer).toString("base64");

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
    const prompt =
      "You are an AI assistant helping illiterate users understand documents.\n" +
      "Analyze this document image and extract all text and important information.\n" +
      "Provide the extracted data in a clear, structured format.";

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: base64Image,
        },
      },
    ]);
    const extractedText = result.response.text();

    return {
      success: true,
      extractedText: extractedText,
    };
  } catch (error) {
    console.error("Error analyzing document:", error);
    throw new HttpsError(
      "internal",
      "Failed to analyze document: " + error.message
    );
  }
});

// Function 2: Chat with Document (Original - for Scanner)
exports.chatWithDocument = onCall({ enforceAppCheck: true }, async (request) => {
  const { imageUrl, extractedText, userMessage, language } = request.data;

  if (!imageUrl || !userMessage) {
    throw new HttpsError(
      "invalid-argument",
      "Image URL and user message are required."
    );
  }

  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }
    const imageBuffer = await response.arrayBuffer();
    const base64Image = Buffer.from(imageBuffer).toString("base64");

    const languageNames = {
      "en-IN": "English",
      "hi-IN": "Hindi (हिंदी)",
      "ta-IN": "Tamil (தமிழ்)",
      "te-IN": "Telugu (తెలుగు)",
      "mr-IN": "Marathi (मराठी)",
      "bn-IN": "Bengali (বাংলা)",
      "gu-IN": "Gujarati (ગુજરાતી)",
      "kn-IN": "Kannada (ಕನ್ನಡ)",
      "ml-IN": "Malayalam (മലയാളം)",
      "pa-IN": "Punjabi (ਪੰਜਾਬੀ)",
      "or-IN": "Odia (ଓଡ଼ିଆ)",
      "as-IN": "Assamese (অসমীয়া)",
    };

    const selectedLanguageName = languageNames[language] || "English";

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

    const prompt =
      `You are an AI assistant helping users understand documents. You have analyzed a document and extracted the following information:\n\n` +
      `${extractedText}\n\n` +
      `The user is asking: "${userMessage}"\n\n` +
      `Please respond to the user's question in ${selectedLanguageName}. ` +
      `Be helpful, clear, and concise. If the question is about specific details in the document, ` +
      `refer to the document image and extracted text to provide accurate information. ` +
      `If the user asks about something not in the document, politely let them know. ` +
      `Keep your response conversational and easy to understand for users who may not be highly literate.`;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: base64Image,
        },
      },
    ]);

    const aiResponse = result.response.text();

    return {
      success: true,
      response: aiResponse,
    };
  } catch (error) {
    console.error("Error in chat:", error);
    throw new HttpsError(
      "internal",
      "Failed to process chat message: " + error.message
    );
  }
});

// ========== DOCUMENT FILLER FUNCTIONS ==========

// Function 3: Analyze Document for Filling (NEW)
exports.analyzeDocumentForFilling = onCall({ enforceAppCheck: true }, async (request) => {
  const imageUrl = request.data.imageUrl;

  if (!imageUrl) {
    console.error("Function called without an imageUrl.");
    throw new HttpsError(
      "invalid-argument",
      "Image URL is required."
    );
  }

  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }
    const imageBuffer = await response.arrayBuffer();
    const base64Image = Buffer.from(imageBuffer).toString("base64");

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });
    const prompt =
      "You are an AI assistant helping users fill out forms and documents with blank fields.\n" +
      "Analyze this document image carefully and:\n" +
      "1. Extract all text present in the document\n" +
      "2. Identify all blank fields, empty spaces, or fields that need to be filled\n" +
      "3. List each field with a clear label (e.g., 'Name:', 'Date:', 'Address:', etc.)\n" +
      "4. Note the type of information expected for each field\n\n" +
      "Provide the analysis in this format:\n" +
      "=== DOCUMENT TEXT ===\n" +
      "[All visible text]\n\n" +
      "=== FIELDS TO FILL ===\n" +
      "Field 1: [Field name] - [Type of data expected]\n" +
      "Field 2: [Field name] - [Type of data expected]\n" +
      "etc.";

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: base64Image,
        },
      },
    ]);
    const extractedText = result.response.text();

    return {
      success: true,
      extractedText: extractedText,
    };
  } catch (error) {
    console.error("Error analyzing document for filling:", error);
    throw new HttpsError(
      "internal",
      "Failed to analyze document: " + error.message
    );
  }
});

// Function 4: Fill Document Field (NEW)
exports.fillDocumentField = onCall({ enforceAppCheck: true }, async (request) => {
  const { imageUrl, extractedText, userMessage, language, filledFields } = request.data;

  if (!imageUrl || !userMessage) {
    throw new HttpsError(
      "invalid-argument",
      "Image URL and user message are required."
    );
  }

  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }
    const imageBuffer = await response.arrayBuffer();
    const base64Image = Buffer.from(imageBuffer).toString("base64");

    const languageNames = {
      "en-IN": "English",
      "hi-IN": "Hindi (हिंदी)",
      "ta-IN": "Tamil (தமிழ்)",
      "te-IN": "Telugu (తెలుగు)",
      "mr-IN": "Marathi (मराठी)",
      "bn-IN": "Bengali (বাংলা)",
      "gu-IN": "Gujarati (ગુજરાતી)",
      "kn-IN": "Kannada (ಕನ್ನಡ)",
      "ml-IN": "Malayalam (മലയാളം)",
      "pa-IN": "Punjabi (ਪੰਜਾਬੀ)",
      "or-IN": "Odia (ଓଡ଼ିଆ)",
      "as-IN": "Assamese (অসমীয়া)",
    };

    const selectedLanguageName = languageNames[language] || "English";

    const filledFieldsText = Object.keys(filledFields || {}).length > 0
      ? "\n\n=== ALREADY FILLED FIELDS ===\n" + Object.entries(filledFields).map(([key, value]) => `${key}: ${value}`).join("\n")
      : "\n\nNo fields have been filled yet.";

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

    const prompt =
      `You are an AI assistant helping users fill out a document. Here's the document analysis:\n\n` +
      `${extractedText}\n` +
      `${filledFieldsText}\n\n` +
      `The user just said: "${userMessage}"\n\n` +
      `Your task:\n` +
      `1. Understand what information the user is providing\n` +
      `2. Match it to the appropriate field(s) in the document\n` +
      `3. Respond in ${selectedLanguageName} confirming what you filled and asking for the next piece of information\n` +
      `4. If the user's input is unclear, ask for clarification\n` +
      `5. If all fields are filled, congratulate them and summarize\n\n` +
      `IMPORTANT: After your response, provide the updated fields in this EXACT format:\n` +
      `[UPDATED_FIELDS]\n` +
      `{"FieldName1": "Value1", "FieldName2": "Value2"}\n` +
      `[/UPDATED_FIELDS]\n\n` +
      `Be conversational, friendly, and guide the user through filling the form step by step.`;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: base64Image,
        },
      },
    ]);

    let aiResponse = result.response.text();

    // Extract updated fields from response
    let updatedFields = filledFields || {};
    const fieldMatch = aiResponse.match(/\[UPDATED_FIELDS\]([\s\S]*?)\[\/UPDATED_FIELDS\]/);

    if (fieldMatch) {
      try {
        const newFields = JSON.parse(fieldMatch[1].trim());
        updatedFields = { ...updatedFields, ...newFields };
        // Remove the fields marker from the response
        aiResponse = aiResponse.replace(/\[UPDATED_FIELDS\][\s\S]*?\[\/UPDATED_FIELDS\]/g, '').trim();
      } catch (e) {
        console.error("Error parsing updated fields:", e);
      }
    }

    return {
      success: true,
      response: aiResponse,
      updatedFields: updatedFields,
    };
  } catch (error) {
    console.error("Error filling document field:", error);
    throw new HttpsError(
      "internal",
      "Failed to process field: " + error.message
    );
  }
});

// Function 5: Generate Filled Document Summary (NEW)
exports.generateFilledDocument = onCall({ enforceAppCheck: true }, async (request) => {
  const { imageUrl, filledFields, language } = request.data;

  if (!imageUrl || !filledFields) {
    throw new HttpsError(
      "invalid-argument",
      "Image URL and filled fields are required."
    );
  }

  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }
    const imageBuffer = await response.arrayBuffer();
    const base64Image = Buffer.from(imageBuffer).toString("base64");

    const languageNames = {
      "en-IN": "English",
      "hi-IN": "Hindi (हिंदी)",
      "ta-IN": "Tamil (தமிழ்)",
      "te-IN": "Telugu (తెలుగు)",
      "mr-IN": "Marathi (मराठी)",
      "bn-IN": "Bengali (বাংলা)",
      "gu-IN": "Gujarati (ગુજરાતી)",
      "kn-IN": "Kannada (ಕನ್ನಡ)",
      "ml-IN": "Malayalam (മലയാളം)",
      "pa-IN": "Punjabi (ਪੰਜਾਬੀ)",
      "or-IN": "Odia (ଓଡ଼ିଆ)",
      "as-IN": "Assamese (অসমীয়া)",
    };

    const selectedLanguageName = languageNames[language] || "English";

    const filledFieldsList = Object.entries(filledFields)
      .map(([key, value]) => `${key}: ${value}`)
      .join("\n");

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

    const prompt =
      `You are an AI assistant. A user has filled out a document with the following information:\n\n` +
      `${filledFieldsList}\n\n` +
      `Please provide a comprehensive summary in ${selectedLanguageName} that:\n` +
      `1. Congratulates the user on completing the form\n` +
      `2. Lists all the filled fields in a clear, organized manner\n` +
      `3. Mentions that this information has been recorded\n` +
      `4. Provides any relevant next steps or advice\n\n` +
      `Keep the tone friendly and encouraging.`;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: base64Image,
        },
      },
    ]);

    const summary = result.response.text();

    return {
      success: true,
      summary: summary,
      filledFields: filledFields,
    };
  } catch (error) {
    console.error("Error generating filled document:", error);
    throw new HttpsError(
      "internal",
      "Failed to generate document: " + error.message
    );
  }
});

// Function 6: Generate Pictogram Help (NEW)
exports.generatePictogramHelp = onCall({ enforceAppCheck: true }, async (request) => {
  const { imageUrl, extractedText, language, filledFields } = request.data;

  if (!imageUrl) {
    throw new HttpsError(
      "invalid-argument",
      "Image URL is required."
    );
  }

  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Image fetch failed with status ${response.status}`);
    }
    const imageBuffer = await response.arrayBuffer();
    const base64Image = Buffer.from(imageBuffer).toString("base64");

    const languageNames = {
      "en-IN": "English",
      "hi-IN": "Hindi (हिंदी)",
      "ta-IN": "Tamil (தமிழ்)",
      "te-IN": "Telugu (తెలుగు)",
      "mr-IN": "Marathi (मराठी)",
      "bn-IN": "Bengali (বাংলা)",
      "gu-IN": "Gujarati (ગુજરાતી)",
      "kn-IN": "Kannada (ಕನ್ನಡ)",
      "ml-IN": "Malayalam (മലയാളം)",
      "pa-IN": "Punjabi (ਪੰਜਾਬੀ)",
      "or-IN": "Odia (ଓଡ଼ିଆ)",
      "as-IN": "Assamese (অসমীয়া)",
    };

    const selectedLanguageName = languageNames[language] || "English";

    const filledFieldsText = Object.keys(filledFields || {}).length > 0
      ? "\n\n=== ALREADY FILLED FIELDS ===\n" + Object.entries(filledFields).map(([key, value]) => `${key}: ${value}`).join("\n")
      : "\n\nNo fields have been filled yet.";

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash-exp" });

    const prompt =
      `You are an AI assistant helping users understand form fields through visual explanations.\n\n` +
      `DOCUMENT ANALYSIS:\n${extractedText}\n` +
      `${filledFieldsText}\n\n` +
      `Based on the document and the fields that still need to be filled, provide:\n\n` +
      `1. Identify the NEXT unfilled field that needs attention\n` +
      `2. Provide a clear, simple explanation in ${selectedLanguageName} about what this field is asking for\n` +
      `3. Give 1-2 examples of what kind of information should be entered\n` +
      `4. Use simple language suitable for users with low literacy\n\n` +
      `IMPORTANT: At the end, suggest ONE appropriate icon name from this list:\n` +
      `person, email, phone, home, location_on, calendar_today, work, badge, credit_card, description, ` +
      `edit, message, account_circle, business, school, family_restroom, male, female, cake, fingerprint, ` +
      `medical_services, local_hospital, help_outline\n\n` +
      `Format your response like this:\n` +
      `[EXPLANATION]\n` +
      `Your clear explanation here with examples\n` +
      `[/EXPLANATION]\n` +
      `[ICON]icon_name[/ICON]`;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: base64Image,
        },
      },
    ]);

    const aiResponse = result.response.text();

    // Extract explanation and icon suggestion
    let explanation = "This field needs information. Please provide the required details.";
    let iconSuggestion = "help_outline";

    const explanationMatch = aiResponse.match(/\[EXPLANATION\]([\s\S]*?)\[\/EXPLANATION\]/);
    const iconMatch = aiResponse.match(/\[ICON\](.*?)\[\/ICON\]/);

    if (explanationMatch) {
      explanation = explanationMatch[1].trim();
    }

    if (iconMatch) {
      iconSuggestion = iconMatch[1].trim();
    }

    return {
      success: true,
      explanation: explanation,
      iconSuggestion: iconSuggestion,
    };
  } catch (error) {
    console.error("Error generating pictogram help:", error);
    throw new HttpsError(
      "internal",
      "Failed to generate visual help: " + error.message
    );
  }
});