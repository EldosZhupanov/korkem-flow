import React from 'react';
import { AlertCircle } from 'lucide-react';
import { Button } from './button';
import { cn } from '@/lib/utils';

export function ErrorState({
  title = 'Ошибка при загрузке данных',
  message,
  onRetry,
  className,
}: {
  title?: string;
  message?: string;
  onRetry?: () => void;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center rounded-2xl border border-destructive/30 bg-destructive/10 p-8 text-center',
        className
      )}
    >
      <AlertCircle className="h-10 w-10 text-destructive-foreground mb-3" />
      <h4 className="text-base font-bold text-foreground mb-1">{title}</h4>
      {message && (
        <p className="max-w-md text-sm text-muted-foreground mb-4">
          {message}
        </p>
      )}
      {onRetry && (
        <Button onClick={onRetry} variant="outline" size="sm">
          Повторить попытку
        </Button>
      )}
    </div>
  );
}
