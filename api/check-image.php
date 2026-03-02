<?php
header('Content-Type: application/json');

// CORS
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed = ['https://real-insta.com', 'https://www.real-insta.com'];
if (in_array($origin, $allowed)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
}
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$base64 = $input['image'] ?? '';
if (!preg_match('/^data:image\/(png|jpe?g|webp|gif);base64,/', $base64) && strlen($base64) < 100) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid image data']);
    exit;
}

// Ensure data URI format
if (!str_starts_with($base64, 'data:image/')) {
    $base64 = 'data:image/jpeg;base64,' . $base64;
}

// =========================================================
// ELA (Error Level Analysis) - 圧縮レベル不整合で加工検出
// =========================================================
function performELA(string $base64Data): array {
    if (!function_exists('imagecreatefromstring')) {
        return ['manipulated' => false, 'reason' => 'GD未対応'];
    }

    $raw = preg_replace('/^data:image\/[^;]+;base64,/', '', $base64Data);
    $imageData = base64_decode($raw);
    if (!$imageData || strlen($imageData) < 100) {
        return ['manipulated' => false, 'reason' => 'decode失敗'];
    }

    $img = @imagecreatefromstring($imageData);
    if (!$img) return ['manipulated' => false, 'reason' => 'image作成失敗'];

    $w = imagesx($img);
    $h = imagesy($img);
    if ($w < 10 || $h < 10) { imagedestroy($img); return ['manipulated' => false]; }

    // 再圧縮 (quality 95) して比較
    ob_start();
    imagejpeg($img, null, 95);
    $recompressed = ob_get_clean();

    $img2 = @imagecreatefromstring($recompressed);
    if (!$img2) { imagedestroy($img); return ['manipulated' => false]; }

    // サンプリング (~10000ピクセル)
    $pixelCount = $w * $h;
    $step = max(1, (int)sqrt($pixelCount / 10000));

    // 8x8グリッドでブロック別解析
    $gridSize = 8;
    $blockW = max(1, (int)($w / $gridSize));
    $blockH = max(1, (int)($h / $gridSize));

    $blockDiffs = array_fill(0, $gridSize, array_fill(0, $gridSize, 0.0));
    $blockCounts = array_fill(0, $gridSize, array_fill(0, $gridSize, 0));
    $totalDiff = 0.0;
    $diffSqSum = 0.0;
    $sampled = 0;

    for ($x = 0; $x < $w; $x += $step) {
        for ($y = 0; $y < $h; $y += $step) {
            $c1 = imagecolorat($img, $x, $y);
            $c2 = imagecolorat($img2, $x, $y);

            $diff = (abs((($c1 >> 16) & 0xFF) - (($c2 >> 16) & 0xFF))
                  + abs((($c1 >> 8) & 0xFF) - (($c2 >> 8) & 0xFF))
                  + abs(($c1 & 0xFF) - ($c2 & 0xFF))) / 3.0;

            $totalDiff += $diff;
            $diffSqSum += $diff * $diff;
            $sampled++;

            $gx = min($gridSize - 1, (int)($x / $blockW));
            $gy = min($gridSize - 1, (int)($y / $blockH));
            $blockDiffs[$gx][$gy] += $diff;
            $blockCounts[$gx][$gy]++;
        }
    }

    imagedestroy($img);
    imagedestroy($img2);

    if ($sampled === 0) return ['manipulated' => false];

    $mean = $totalDiff / $sampled;
    $variance = ($diffSqSum / $sampled) - ($mean * $mean);
    $stdDev = sqrt(max(0, $variance));

    // ブロック別の平均誤差
    $blockMeans = [];
    for ($gx = 0; $gx < $gridSize; $gx++) {
        for ($gy = 0; $gy < $gridSize; $gy++) {
            if ($blockCounts[$gx][$gy] > 0) {
                $blockMeans[] = $blockDiffs[$gx][$gy] / $blockCounts[$gx][$gy];
            }
        }
    }

    // 最大ブロック偏差
    $maxBlockDev = 0;
    foreach ($blockMeans as $bm) {
        $dev = abs($bm - $mean);
        if ($dev > $maxBlockDev) $maxBlockDev = $dev;
    }

    $varRatio = ($mean > 0.5) ? ($stdDev / $mean) : 0;
    $blockRatio = ($mean > 0.5) ? ($maxBlockDev / $mean) : 0;

    // 保守的な閾値: 明らかな部分加工のみ検出
    // varRatio > 1.8 かつ maxBlockDev > 12 → ブロック間の圧縮差が大きい
    // blockRatio > 2.5 かつ maxBlockDev > 10 → 特定ブロックだけ極端に違う
    $manipulated = ($varRatio > 1.8 && $maxBlockDev > 12)
                || ($blockRatio > 2.5 && $maxBlockDev > 10);

    return [
        'manipulated' => $manipulated,
        'mean' => round($mean, 2),
        'std_dev' => round($stdDev, 2),
        'var_ratio' => round($varRatio, 2),
        'max_block_dev' => round($maxBlockDev, 2),
        'block_ratio' => round($blockRatio, 2),
    ];
}

// === Step 1: ELA解析 ===
$elaResult = performELA($base64);
error_log("check-image ELA: " . json_encode($elaResult));

// ELAが明確に加工を検出 → GPT呼び出し不要、即ブロック（API費用節約）
if ($elaResult['manipulated']) {
    echo json_encode([
        'allowed' => false,
        'reason' => '画像の部分的な加工が検出されました（圧縮レベル解析）',
        'check' => 'ela',
    ]);
    exit;
}

// === Step 2: GPT-5.2 Vision Check (Detailed Forensics) ===
$apiKey = getenv('OPENAI_API_KEY');
if (!$apiKey) {
    http_response_code(500);
    echo json_encode(['error' => 'API key not configured']);
    exit;
}

$systemPrompt = <<<'SYSPROMPT'
You are an expert image forensics analyst. Your task is to determine whether a given photograph has been digitally manipulated, AI-generated, or is an authentic unedited photograph.

## Analysis Criteria

Analyze the image across the following dimensions and assign a confidence score (0-100) for each:

### A. AI Generation Indicators
- Unnatural skin texture (too smooth, waxy, plastic-like)
- Distorted or inconsistent fingers, hands, teeth, ears
- Asymmetric facial features that defy natural human anatomy
- Text or letters that are garbled, misspelled, or nonsensical
- Background objects that blend, morph, or lack structural logic
- Repeating patterns or textures that tile unnaturally
- Inconsistent art style mixing (photorealistic face on painted body, etc.)

### B. Photo Manipulation Indicators (Photoshop, FaceApp, etc.)
- Unnatural body proportions (waist too thin, muscles too large, head-to-body ratio off)
- Warped or bent lines near edited areas (doorframes, tiles, edges)
- Inconsistent lighting direction or shadow angles across subjects
- Skin that is unnaturally smooth in specific areas while rough in others (selective smoothing)
- Clone stamp artifacts: repeated pixel patterns or textures
- Abrupt changes in resolution, noise level, or compression between regions
- Unnatural color boundaries or halos around subjects (poor masking)
- Missing or inconsistent reflections in mirrors, glasses, water, eyes

### C. Authenticity Indicators (signs the photo is REAL)
- Consistent noise/grain pattern throughout the entire image
- Natural lens distortion, chromatic aberration, depth of field
- Consistent lighting and shadow geometry
- Natural skin texture with pores, fine hairs, imperfections
- Proper perspective geometry and vanishing points
- Natural motion blur consistent with camera movement

## Output Format

You MUST respond ONLY in the following JSON format. No additional text, no markdown fences:

{"verdict":"authentic"|"manipulated"|"ai_generated"|"suspicious","confidence":0-100,"manipulation_score":0-100,"ai_generation_score":0-100,"flags":[{"category":"ai_generation"|"photo_manipulation"|"filter"|"composite","description":"specific finding","severity":"low"|"medium"|"high"}],"summary_ja":"日本語での簡潔な判定理由","recommendation":"approve"|"review"|"reject"}

## Decision Thresholds

- "approve": High confidence authentic (manipulation_score < 20 AND ai_generation_score < 15)
- "reject": Clearly manipulated or AI-generated (manipulation_score > 70 OR ai_generation_score > 70)
- "review": Everything in between

## Important Rules

1. Standard camera filters (Instagram-style color grading, vignette) should NOT be flagged as manipulation. Only flag filters that alter geometry, body shape, or facial structure.
2. Simple cropping and rotation are NOT manipulation.
3. Standard HDR processing and exposure adjustment are NOT manipulation.
4. Beauty filters that alter facial structure (bigger eyes, slimmer jaw, skin smoothing) ARE manipulation.
5. Face swaps and deepfakes are manipulation — flag with high severity.
6. Memes with obvious text overlays: flag as "manipulated" but low severity.
7. Screenshots of other content: flag as "suspicious" for review.
8. When in doubt, lean toward "suspicious" + "review" rather than false rejection.
SYSPROMPT;

$payload = [
    'model' => 'gpt-5.2',
    'messages' => [
        [
            'role' => 'system',
            'content' => $systemPrompt,
        ],
        [
            'role' => 'user',
            'content' => [
                ['type' => 'text', 'text' => 'Analyze this photograph for signs of digital manipulation or AI generation. Examine every detail carefully and respond in the required JSON format only.'],
                ['type' => 'image_url', 'image_url' => ['url' => $base64, 'detail' => 'high']],
            ],
        ],
    ],
    'max_completion_tokens' => 1000,
    'temperature' => 0.1,
];

$ch = curl_init('https://api.openai.com/v1/chat/completions');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        "Authorization: Bearer $apiKey",
    ],
    CURLOPT_POSTFIELDS => json_encode($payload),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 45,
]);
$resp = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    error_log("check-image GPT: HTTP $httpCode, resp=" . substr($resp, 0, 300));
    echo json_encode(['allowed' => true, 'reason' => 'チェックをスキップしました']);
    exit;
}

$data = json_decode($resp, true);
$content = $data['choices'][0]['message']['content'] ?? '';

error_log("check-image GPT raw: " . substr($content, 0, 500));

// Extract JSON — handle nested braces (flags array contains objects)
$result = json_decode($content, true);
if (!$result) {
    // Try extracting JSON from markdown fences or surrounding text
    if (preg_match('/\{[\s\S]*"verdict"[\s\S]*"recommendation"[\s\S]*\}/', $content, $m)) {
        $result = json_decode($m[0], true);
    }
}

error_log("check-image GPT parsed: " . json_encode($result));

if ($result && isset($result['recommendation'])) {
    $verdict = $result['verdict'] ?? 'suspicious';
    $confidence = (int)($result['confidence'] ?? 0);
    $manipScore = (int)($result['manipulation_score'] ?? 0);
    $aiScore = (int)($result['ai_generation_score'] ?? 0);
    $recommendation = $result['recommendation'] ?? 'review';
    $summaryJa = $result['summary_ja'] ?? '';
    $flags = $result['flags'] ?? [];

    // Server-side enforcement: don't trust GPT's recommendation alone
    // GPT often returns manip=48 for clearly filtered photos — use aggressive thresholds
    $blocked = ($recommendation === 'reject')
            || ($manipScore >= 40)       // 40+ manipulation → block
            || ($aiScore >= 40)          // 40+ AI generation → block
            || ($verdict === 'manipulated')
            || ($verdict === 'ai_generated')
            || ($verdict === 'suspicious' && $manipScore >= 35);

    $output = [
        'allowed' => !$blocked,
        'reason' => $summaryJa,
        'check' => 'gpt',
        'verdict' => $verdict,
        'confidence' => $confidence,
        'manipulation_score' => $manipScore,
        'ai_generation_score' => $aiScore,
        'recommendation' => $recommendation,
        'flags' => $flags,
        'ela' => $elaResult,
    ];
    error_log("check-image: verdict=$verdict, manip=$manipScore, ai=$aiScore, rec=$recommendation, allowed=" . ($output['allowed'] ? 'true' : 'false'));
    echo json_encode($output);
} else {
    error_log("check-image: GPT parse failed, allowing. content=" . substr($content, 0, 200));
    echo json_encode(['allowed' => true, 'reason' => 'チェックをスキップしました']);
}
