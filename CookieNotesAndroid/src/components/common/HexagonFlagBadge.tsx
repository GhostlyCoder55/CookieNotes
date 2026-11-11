import React from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { ClipPath, Defs, G, Line, Path, Rect } from 'react-native-svg';
import type { AppLanguage } from '../../localization/i18n';

interface Props {
  language: AppLanguage;
  width?: number;
  height?: number;
}

function buildRoundedHexagonPath(w: number, h: number, cornerRadius: number): string {
  const radius = Math.min(w / Math.sqrt(3), h / 2);
  const cx = w / 2;
  const cy = h / 2;
  const vertices: Array<{ x: number; y: number }> = [];
  for (let i = 0; i < 6; i += 1) {
    const angle = ((i * 60 - 90) * Math.PI) / 180;
    vertices.push({
      x: cx + radius * Math.cos(angle),
      y: cy + radius * Math.sin(angle),
    });
  }

  const r = Math.min(cornerRadius, radius * 0.45);
  const commands: string[] = [];

  for (let i = 0; i < 6; i += 1) {
    const prev = vertices[(i + 5) % 6];
    const curr = vertices[i];
    const next = vertices[(i + 1) % 6];

    const v1x = prev.x - curr.x;
    const v1y = prev.y - curr.y;
    const len1 = Math.hypot(v1x, v1y) || 1;
    const p1x = curr.x + (v1x / len1) * r;
    const p1y = curr.y + (v1y / len1) * r;

    const v2x = next.x - curr.x;
    const v2y = next.y - curr.y;
    const len2 = Math.hypot(v2x, v2y) || 1;
    const p2x = curr.x + (v2x / len2) * r;
    const p2y = curr.y + (v2y / len2) * r;

    if (i === 0) {
      commands.push(`M ${p1x.toFixed(2)} ${p1y.toFixed(2)}`);
    } else {
      commands.push(`L ${p1x.toFixed(2)} ${p1y.toFixed(2)}`);
    }
    commands.push(`Q ${curr.x.toFixed(2)} ${curr.y.toFixed(2)} ${p2x.toFixed(2)} ${p2y.toFixed(2)}`);
  }
  commands.push('Z');
  return commands.join(' ');
}

export function HexagonFlagBadge({ language, width = 68, height = 78 }: Props) {
  const vw = 72;
  const vh = 82;
  const hexPath = buildRoundedHexagonPath(vw, vh, 7);
  const clipId = `hexClip-${language}`;

  const s = Math.min(vw, vh);
  const radius = Math.min(vw / Math.sqrt(3), vh / 2);
  const cx = vw / 2;
  const cy = vh / 2;
  const dx = ((radius * Math.sqrt(3)) / 2) * 1.25;
  const dy = (radius / 2) * 1.25;

  return (
    <View
      style={[styles.container, { width, height }]}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Svg width={width} height={height} viewBox={`0 0 ${vw} ${vh}`}>
        <Defs>
          <ClipPath id={clipId}>
            <Path d={hexPath} />
          </ClipPath>
        </Defs>

        <G clipPath={`url(#${clipId})`}>
          {language === 'en' && (
            <>
              <Rect x={0} y={0} width={vw} height={vh} fill="#012169" />
              <Line
                x1={cx - dx}
                y1={cy - dy}
                x2={cx + dx}
                y2={cy + dy}
                stroke="#FFFFFF"
                strokeWidth={s * 0.17}
              />
              <Line
                x1={cx + dx}
                y1={cy - dy}
                x2={cx - dx}
                y2={cy + dy}
                stroke="#FFFFFF"
                strokeWidth={s * 0.17}
              />
              <Line
                x1={cx - dx}
                y1={cy - dy}
                x2={cx + dx}
                y2={cy + dy}
                stroke="#C8102E"
                strokeWidth={s * 0.075}
              />
              <Line
                x1={cx + dx}
                y1={cy - dy}
                x2={cx - dx}
                y2={cy + dy}
                stroke="#C8102E"
                strokeWidth={s * 0.075}
              />
              <Rect
                x={(vw - s * 0.27) / 2}
                y={0}
                width={s * 0.27}
                height={vh}
                fill="#FFFFFF"
              />
              <Rect
                x={0}
                y={(vh - s * 0.27) / 2}
                width={vw}
                height={s * 0.27}
                fill="#FFFFFF"
              />
              <Rect
                x={(vw - s * 0.16) / 2}
                y={0}
                width={s * 0.16}
                height={vh}
                fill="#C8102E"
              />
              <Rect
                x={0}
                y={(vh - s * 0.16) / 2}
                width={vw}
                height={s * 0.16}
                fill="#C8102E"
              />
            </>
          )}

          {language === 'fr' && (
            <>
              <Rect x={0} y={0} width={vw / 3} height={vh} fill="#0055A4" />
              <Rect x={vw / 3} y={0} width={vw / 3} height={vh} fill="#FFFFFF" />
              <Rect x={(vw * 2) / 3} y={0} width={vw / 3} height={vh} fill="#EF4135" />
            </>
          )}

          {language === 'es' && (
            <>
              <Rect x={0} y={0} width={vw} height={vh * 0.25} fill="#AA151B" />
              <Rect x={0} y={vh * 0.25} width={vw} height={vh * 0.5} fill="#F1BF00" />
              <Rect x={0} y={vh * 0.75} width={vw} height={vh * 0.25} fill="#AA151B" />
              {/* Simplified Spanish coat-of-arms emblem accent */}
              <Rect
                x={vw * 0.24}
                y={vh * 0.36}
                width={14}
                height={20}
                rx={4}
                fill="#AA151B"
              />
              <Rect
                x={vw * 0.26}
                y={vh * 0.31}
                width={10}
                height={4}
                rx={2}
                fill="#C89B1E"
              />
            </>
          )}
        </G>

        <Path
          d={hexPath}
          fill="none"
          stroke="rgba(255, 255, 255, 0.16)"
          strokeWidth={1.2}
        />
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 3,
  },
});
