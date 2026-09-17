import React from 'react';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

export function LoadingState({
  message = 'Загрузка данных...',
  className,
}: {
  message?: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center py-16 text-muted-foreground gap-3',
        className
      )}
    >
      <Loader2 className="h-8 w-8 animate-spin text-primary" />
      <span className="text-sm font-medium">{message}</span>
    </div>
  );
}
