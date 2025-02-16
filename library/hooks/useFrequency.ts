import { useEffect, useState } from 'react';
import { rnfftFrequency } from '../rnfftfrequency';

export function useFrequency() {
  const [frequency, setFrequency] = useState(0);

  useEffect(() => {
    rnfftFrequency.addListener('onFrequencyDetected', (_frequency: number) => {
      setFrequency(_frequency);
    });
  }, []);

  return frequency;
}
