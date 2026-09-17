import React from 'react';
import { cn } from '@/lib/utils';
import { LucideIcon, FolderOpen } from 'lucide-react';
import { Button } from './button';

interface EmptyStateProps {
  icon?: LucideIcon;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({
  icon: Icon = FolderOpen,
  title,
  description,
  actionLabel,
  onAction,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-card/50 p-12 text-center',
        className
      )}
    >
      <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-secondary text-muted-foreground mb-4">
        <Icon className="h-8 w-8" />
      </div>
      <h3 className="text-lg font-bold text-foreground mb-2">{title}</h3>
      <p className="max-w-sm text-sm text-muted-foreground mb-6 leading-relaxed">
        {description}
      </p>
      {action ? (
        action
      ) : actionLabel && onAction ? (
        <Button onClick={onAction} variant="default">
          {actionLabel}
        </Button>
      ) : null}
    </div>
  );
}
