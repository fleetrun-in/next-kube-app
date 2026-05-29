export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 bg-zinc-50 px-6 text-center font-sans dark:bg-zinc-950">
      <p className="text-sm font-medium uppercase tracking-widest text-zinc-500">
        next-kube-app
      </p>
      <h1 className="text-4xl font-semibold text-zinc-900 dark:text-zinc-50">
        Hello from Fleetrun
      </h1>
      <p className="max-w-md text-lg text-zinc-600 dark:text-zinc-400">
        The Next-Kube app is deployed on your cluster and updated automatically
        when changes merge to  <code className="rounded bg-zinc-200 px-1.5 py-0.5 dark:bg-zinc-800">main</code>.
      </p>
    </main>
  );
}
