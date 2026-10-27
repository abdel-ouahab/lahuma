import React from 'react';
import './course-design-cards.css';

export type CardColor = 'green' | 'orange' | 'red' | 'blue';

/* ------------------------------------------------------------------ icons */

const EllipsisIcon: React.FC = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" width="20" height="20" aria-hidden="true">
    <path fillRule="evenodd" d="M10.5 6a1.5 1.5 0 1 1 3 0 1.5 1.5 0 0 1-3 0Zm0 6a1.5 1.5 0 1 1 3 0 1.5 1.5 0 0 1-3 0Zm0 6a1.5 1.5 0 1 1 3 0 1.5 1.5 0 0 1-3 0Z" clipRule="evenodd" />
  </svg>
);

const AddIcon: React.FC = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" width="20" height="20" aria-hidden="true">
    <path fillRule="evenodd" d="M12 3.75a.75.75 0 0 1 .75.75v6.75h6.75a.75.75 0 0 1 0 1.5h-6.75v6.75a.75.75 0 0 1-1.5 0v-6.75H4.5a.75.75 0 0 1 0-1.5h6.75V4.5a.75.75 0 0 1 .75-.75Z" clipRule="evenodd" />
  </svg>
);

/* -------------------------------------------------------------- CardShell */

interface CardShellProps {
  color?: CardColor;
  /** Small label on the top-left (date, category, metric name…). */
  eyebrow?: React.ReactNode;
  /** Top-right slot. Pass `null` to hide; defaults to the ellipsis icon. */
  action?: React.ReactNode;
  /** Bottom strip. */
  footer?: React.ReactNode;
  /** 0–100. Renders the progress row when provided. */
  progress?: number;
  progressLabel?: React.ReactNode;
  interactive?: boolean;
  as?: 'div' | 'article' | 'section';
  className?: string;
  children?: React.ReactNode;
}

/** Generic dark, colour-accented card used for every card in the app. */
export const CardShell: React.FC<CardShellProps> = ({
  color = 'green',
  eyebrow,
  action,
  footer,
  progress,
  progressLabel,
  interactive,
  as: Tag = 'div',
  className = '',
  children,
}) => {
  const pct = progress === undefined ? undefined : Math.max(0, Math.min(100, progress));
  return (
    <Tag
      className={`cdc ${color}${interactive ? ' cdc-interactive' : ''} ${className}`.trim()}
      style={pct === undefined ? undefined : ({ '--progress': `${pct}%` } as React.CSSProperties)}
    >
      <div className="cdc-header">
        <div className="cdc-eyebrow">{eyebrow}</div>
        {action === undefined ? <EllipsisIcon /> : action}
      </div>
      <div className="cdc-body">
        {children}
        {pct !== undefined && (
          <div className="cdc-progress">
            <span>Progress</span>
            <div className="cdc-progress-bar" />
            <span>{progressLabel ?? `${Math.round(pct)}%`}</span>
          </div>
        )}
      </div>
      {footer && <div className="cdc-footer">{footer}</div>}
    </Tag>
  );
};

/* ------------------------------------------------- Card (original design) */

export interface CardData {
  id: number;
  colorClass: CardColor | string;
  date: string;
  title: string;
  description: string;
  progressPercent: string;
  progressValue: string;
  imgSrc1?: string;
  imgAlt1?: string;
  imgSrc2?: string;
  imgAlt2?: string;
  countdownText: string;
}

const Card: React.FC<{ data: CardData }> = ({ data }) => {
  const { colorClass, date, title, description, progressPercent, progressValue,
    imgSrc1, imgAlt1, imgSrc2, imgAlt2, countdownText } = data;

  return (
    <CardShell
      color={colorClass as CardColor}
      eyebrow={date}
      progress={parseFloat(progressPercent)}
      progressLabel={progressValue}
      footer={
        <>
          <ul className="cdc-avatars">
            {imgSrc1 && <li><img src={imgSrc1} alt={imgAlt1 || 'user avatar'} /></li>}
            {imgSrc2 && <li><img src={imgSrc2} alt={imgAlt2 || 'user avatar'} /></li>}
            <li><a href="#" className="cdc-btn-add" aria-label="Add member"><AddIcon /></a></li>
          </ul>
          <a href="#" className="cdc-btn-countdown">{countdownText}</a>
        </>
      }
    >
      <h3>{title}</h3>
      <p>{description}</p>
    </CardShell>
  );
};

export default Card;
